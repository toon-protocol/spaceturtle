import QtQuick
import Quickshell
import Quickshell.Io

// The headless half of the plugin, one per shell. It runs the `relay-events`
// script next to this file on a timer and holds what it printed; the bar turtle
// and the panel are views of it, so every monitor's bar shows the same state.
// Nothing else in the plugin starts a process.
Item {
  id: root

  // Injected by the shell.
  property var shell: null

  readonly property string pluginId: "toon.spaceturtle"

  // A service gets no settings of its own; they are on the bar entry in shell.json:
  // { "id": "toon.spaceturtle", "interval": 30, "limit": 40 }
  readonly property var settings: {
    var layout = shell && shell.barConfig ? shell.barConfig.layout : null
    var sections = ["left", "center", "right"]
    for (var s = 0; layout && s < sections.length; s++) {
      var entries = layout[sections[s]] || []
      for (var i = 0; i < entries.length; i++)
        if (entries[i] && entries[i].id === pluginId) return entries[i]
    }
    return ({})
  }
  readonly property int refreshSeconds: Math.max(5, Number(settings.interval) || 30)
  readonly property int eventLimit: Math.max(1, Number(settings.limit) || 40)
  // Which TurtleIcon drawing to use, and whether the panel lists them all to choose from.
  readonly property int iconVariant: Number(settings.icon) || 1
  readonly property bool iconPreview: settings.iconPreview === true

  readonly property string script: Qt.resolvedUrl("relay-events").toString().replace(/^file:\/\//, "")

  readonly property string requestScript: Qt.resolvedUrl("request").toString().replace(/^file:\/\//, "")

  property bool loaded: false
  property bool online: false
  property string relayName: ""
  // pubkey -> the parsed kind 0 metadata of its newest profile event.
  property var profiles: ({})
  // The agent identity's own key, and pubkey -> the keys its newest follow list names.
  property string selfPubkey: ""
  property var followMap: ({})
  // This node's ILP and connector addresses, from the relay's NIP-11 document.
  property string nodeIlp: ""
  property string nodeConnector: ""
  // How many hold a subscription to this relay's live feed; -1 while it is not sold.
  property int subscribers: -1
  // What the agent identity signed, newest first, and when it last did something (0 for never).
  property var activity: []
  property real lastActive: 0
  // The rest of the relay's feed: the Network.
  property var events: []
  // Every Request, newest first; the agent answers them in its next session.
  property var requests: []
  readonly property int waitingCount: requests.filter(function(r) { return r.state === "waiting" }).length

  // True while the panel is open. Newest created_at seen in the panel; anything
  // newer puts the dot on the turtle.
  property bool looking: false
  property real seenAt: 0
  readonly property real newestAt: Math.max(events.length > 0 ? events[0].created_at : 0, lastActive)
  readonly property bool hasUnseen: loaded && newestAt > seenAt

  // Where the panel was, kept here because the panel is unloaded when it closes.
  // Sections are numbered as their keys are, from 1; Activity is 1, Network 2 and Requests 4.
  readonly property int activitySection: 1
  readonly property int networkSection: 2
  readonly property int requestsSection: 4
  property int section: activitySection
  property int cursor: 0
  // The Activity's cursor.
  property int activityCursor: 0
  // The Requests section's cursor.
  property int requestCursor: 0
  // The author page being shown in Network; empty while the feed is.
  property string profilePubkey: ""
  // The feed's cursor, to come back to from an author page.
  property int feedCursor: 0

  onLookingChanged: if (looking) seenAt = newestAt

  // Asked for while a fetch runs, another follows it, so it sees what changed since.
  property bool refreshAgain: false
  function refresh() {
    if (!fetchProc.running) fetchProc.running = true
    else refreshAgain = true
  }

  function applyReport(report) {
    var map = {}
    var profiles = report.profiles || []
    // Oldest first so a newer profile event overwrites an older one.
    profiles.sort(function(a, b) { return a.created_at - b.created_at })
    for (var i = 0; i < profiles.length; i++) {
      try {
        var meta = JSON.parse(profiles[i].content)
        if (meta !== null && typeof meta === "object") map[profiles[i].pubkey] = meta
      } catch (e) {}
    }
    // pubkey -> followed keys, from each author's newest kind 3.
    var follows = report.follows || []
    follows.sort(function(a, b) { return a.created_at - b.created_at })
    var followed = {}
    for (var f = 0; f < follows.length; f++) {
      var keys = []
      var tags = follows[f].tags || []
      for (var t = 0; t < tags.length; t++)
        if (tags[t][0] === "p" && tags[t].length > 1) keys.push(String(tags[t][1]))
      followed[follows[f].pubkey] = keys
    }

    var list = report.events || []
    list.sort(function(a, b) { return b.created_at - a.created_at })

    // The cursor stays on its event when newer ones arrive above it.
    if (root.profilePubkey === "") root.cursor = indexAfter(root.events, list, root.cursor)
    else root.feedCursor = indexAfter(root.events, list, root.feedCursor)

    var acts = report.activity || []
    acts.sort(function(a, b) { return b.created_at - a.created_at })
    root.activityCursor = indexAfter(root.activity, acts, root.activityCursor)

    var first = !root.loaded
    root.profiles = map
    root.followMap = followed
    root.selfPubkey = report.self || ""
    var node = report.node || ({})
    root.nodeIlp = typeof node.ilp_address === "string" ? node.ilp_address.trim() : ""
    root.nodeConnector = typeof node.connector === "string" ? node.connector.trim() : ""
    root.subscribers = typeof report.subscribers === "number" ? report.subscribers : -1
    root.activity = acts
    root.lastActive = typeof report.last_active === "number" ? report.last_active : 0
    root.events = list
    var reqs = report.requests || []
    reqs.sort(function(a, b) { return b.created_at - a.created_at })
    root.requestCursor = indexAfter(root.requests, reqs, root.requestCursor)
    root.requests = reqs
    root.online = report.online === true
    root.relayName = report.name || ""
    root.loaded = true
    // Nothing is "new" on the first load, nor while the panel is showing it.
    if (first || root.looking) root.seenAt = root.newestAt
  }

  // Where the event at `index` of `before` is in `after`; `index` if it is gone.
  function indexAfter(before, after, index) {
    var id = before[index] ? before[index].id : undefined
    if (id === undefined) return index
    for (var i = 0; i < after.length; i++)
      if (after[i].id === id) return i
    return index
  }

  function field(pubkey, name) {
    var meta = profiles[pubkey]
    var value = meta ? meta[name] : undefined
    return typeof value === "string" ? value.trim() : ""
  }

  function nameOf(pubkey) {
    return field(pubkey, "display_name") || field(pubkey, "name") || String(pubkey || "").slice(0, 8)
  }

  function eventsBy(pubkey) {
    // The agent's events are only in the Activity, everyone else's only in the Network.
    var all = pubkey === selfPubkey ? activity : events
    return all.filter(function(e) { return e.pubkey === pubkey })
  }

  // The event an Activity entry refers to, if the feed holds it.
  function eventById(id) {
    var all = activity.concat(events)
    for (var i = 0; i < all.length; i++)
      if (all[i].id === id) return all[i]
    return null
  }

  // Asks the Network to show an event on its author's page, with the cursor on it.
  signal eventOpened(string id)

  // Opens an Activity entry's event: the event it refers to if the feed holds
  // it, else the entry's own, on its author's page in the Network. The feed's
  // place is kept for Esc.
  function openActivity(entry) {
    // A Request's outcome: what the agent published, or the Request and its reason.
    if (entry.request) {
      if (entry.refers_to && eventById(entry.refers_to)) openEvent(entry.refers_to)
      else { requestCursor = Math.max(0, requests.map(function(r) { return r.id }).indexOf(entry.request.id)); section = requestsSection }
      return
    }
    var target = (entry.refers_to ? eventById(entry.refers_to) : null) || entry
    if (profilePubkey === "") feedCursor = cursor
    profilePubkey = target.pubkey
    cursor = 0
    section = networkSection
    eventOpened(target.id)
  }

  // Opens an event on its author's page in the Network; false if the relay does not hold it.
  function openEvent(id) {
    var target = eventById(id)
    if (!target) return false
    if (profilePubkey === "") feedCursor = cursor
    profilePubkey = target.pubkey
    cursor = 0
    section = networkSection
    eventOpened(target.id)
    return true
  }

  // Writes a Request, or withdraws a waiting one. The text goes to the script
  // as an argument, never through a shell.
  property var pendingCommands: []
  function submitRequest(text) {
    if (String(text).trim() === "") return
    runRequest([requestScript, "add", "--", String(text)])
  }
  function withdrawRequest(id) {
    runRequest([requestScript, "withdraw", String(id)])
  }
  function runRequest(command) {
    pendingCommands = pendingCommands.concat([command])
    if (!requestProc.running) nextRequestCommand()
  }
  function nextRequestCommand() {
    if (pendingCommands.length === 0) return
    requestProc.command = pendingCommands[0]
    pendingCommands = pendingCommands.slice(1)
    requestProc.running = true
  }

  function followingCount(pubkey) {
    return (followMap[pubkey] || []).length
  }

  function followerCount(pubkey) {
    var count = 0
    for (var author in followMap)
      if (followMap[author].indexOf(pubkey) !== -1) count++
    return count
  }

  function copy(value) {
    if (value === "") return
    // Passed as an argument, never through a shell: the value comes from a profile.
    Quickshell.execDetached(["wl-copy", "--", value])
  }

  // Opens a web address in the browser.
  function openUrl(url) {
    if (/^https?:\/\//.test(url)) Quickshell.execDetached(["xdg-open", url])
  }

  Process {
    id: fetchProc
    command: [root.script, String(root.eventLimit)]
    onExited: if (root.refreshAgain) { root.refreshAgain = false; Qt.callLater(root.refresh) }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.applyReport(JSON.parse(String(text || "").trim()))
        } catch (e) {
          // Keep the last good feed visible.
          root.online = false
          root.loaded = true
        }
      }
    }
  }

  Process {
    id: requestProc
    onExited: {
      root.refresh()
      root.nextRequestCommand()
    }
  }

  Timer {
    interval: root.refreshSeconds * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
