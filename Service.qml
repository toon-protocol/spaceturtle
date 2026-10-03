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
  // Events a thread needs that the feed's limit left out.
  property var context: []

  // True while the panel is open. Newest created_at seen in the panel; anything
  // newer puts the dot on the turtle.
  property bool looking: false
  property real seenAt: 0
  readonly property real newestAt: Math.max(events.length > 0 ? events[0].created_at : 0, lastActive)
  readonly property bool hasUnseen: loaded && newestAt > seenAt

  // Where the panel was, kept here because the panel is unloaded when it closes.
  // Sections are numbered as their keys are, from 1; Activity is 1 and Network 2.
  readonly property int activitySection: 1
  readonly property int networkSection: 2
  property int section: activitySection
  property int cursor: 0
  // The Activity's cursor.
  property int activityCursor: 0
  // What Network shows: a thread (the id of the event it was opened on), an
  // author page (a pubkey), or, while both are empty, the feed.
  property string threadId: ""
  property string profilePubkey: ""
  // The views Esc comes back to, oldest first, each { profile, thread, cursor };
  // empty while the feed shows, else the first is the feed.
  property var trail: []

  onLookingChanged: if (looking) seenAt = newestAt

  function refresh() {
    if (!fetchProc.running) fetchProc.running = true
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
    if (root.trail.length === 0) {
      if (root.profilePubkey === "" && root.threadId === "") root.cursor = indexAfter(root.events, list, root.cursor)
    } else if (root.trail[0].profile === "" && root.trail[0].thread === "") {
      var views = root.trail.slice()
      views[0] = { profile: "", thread: "", cursor: indexAfter(root.events, list, views[0].cursor) }
      root.trail = views
    }
    // In a thread too, showing or kept for Esc: its rows before, by thread id.
    var threadsBefore = {}
    root.trail.concat([{ thread: root.threadId }]).forEach(function(view) {
      if (view.thread !== "") threadsBefore[view.thread] = threadRows(view.thread)
    })

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
    root.context = report.context || []
    root.trail = root.trail.map(function(view) {
      if (view.thread === "") return view
      return { profile: view.profile, thread: view.thread,
        cursor: indexAfter(threadsBefore[view.thread], threadRows(view.thread), view.cursor) }
    })
    if (root.threadId !== "") root.cursor = indexAfter(threadsBefore[root.threadId], threadRows(root.threadId), root.cursor)
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
    // The agent's events are only in the Activity, everyone else's only in the
    // Network; either may have more that only a thread brought in.
    var all = (pubkey === selfPubkey ? activity : events).concat(context)
    return all.filter(function(e) { return e.pubkey === pubkey })
      .sort(function(a, b) { return b.created_at - a.created_at })
  }

  // An event the relay held at the last refresh, wherever it was found.
  function eventById(id) {
    var all = [activity, events, context]
    for (var l = 0; l < all.length; l++)
      for (var i = 0; i < all[l].length; i++)
        if (all[l][i].id === id) return all[l][i]
    return null
  }

  // Asks the Network to start a view at the top of its page, with the cursor
  // restored and nothing copied.
  signal viewOpened()

  // The conversation an event is part of, in reading order: from the event at
  // its top (a placeholder, if the relay lacks that one) down through what
  // refers to each, oldest first. Each row is the event with its `depth`, or
  // { missing: true, id } for an event the relay does not hold.
  function threadRows(id) {
    var focus = eventById(id)
    if (!focus) return []
    var top = focus
    var seen = {}
    seen[top.id] = true
    while (top.refers_to) {
      var parent = eventById(top.refers_to)
      if (!parent || seen[parent.id]) break
      seen[parent.id] = true
      top = parent
    }
    var rows = []
    if (top.refers_missing === true)
      rows.push({ missing: true, id: top.refers_to, depth: 0, pubkey: "", created_at: 0, parts: ({}) })
    var visited = {}
    function walk(event, depth) {
      if (visited[event.id]) return
      visited[event.id] = true
      var row = {}
      for (var key in event) row[key] = event[key]
      row.depth = depth
      rows.push(row)
      var kids = (event.referenced_by || []).map(eventById).filter(function(e) { return e !== null })
      kids.sort(function(a, b) { return a.created_at - b.created_at })
      for (var k = 0; k < kids.length; k++) walk(kids[k], depth + 1)
    }
    walk(top, rows.length)
    return rows
  }

  // Remembers the view showing, to come back to with Esc.
  function pushView() {
    var views = trail.slice()
    views.push({ profile: profilePubkey, thread: threadId, cursor: cursor })
    trail = views
  }

  // Shows the thread an event is in, with the cursor on the event.
  function openThread(id) {
    if (!eventById(id)) return
    pushView()
    threadId = id
    profilePubkey = ""
    var rows = threadRows(id)
    cursor = 0
    for (var i = 0; i < rows.length; i++)
      if (rows[i].id === id) { cursor = i; break }
    section = networkSection
    viewOpened()
  }

  // Shows an author's page.
  function openAuthor(pubkey) {
    if (!pubkey) return
    pushView()
    threadId = ""
    profilePubkey = pubkey
    cursor = 0
    section = networkSection
    viewOpened()
  }

  // Esc in Network: back to the view before. False when the feed is showing.
  function goBack() {
    if (trail.length === 0) return false
    var views = trail.slice()
    var view = views.pop()
    trail = views
    profilePubkey = view.profile
    threadId = view.thread
    cursor = view.cursor
    return true
  }

  // Opens an Activity entry: the thread of the event it refers to if the feed
  // holds it, else of the entry itself.
  function openActivity(entry) {
    var target = (entry.refers_to ? eventById(entry.refers_to) : null) || entry
    openThread(target.id)
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

  Timer {
    interval: root.refreshSeconds * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
