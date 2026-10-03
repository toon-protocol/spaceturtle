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
  readonly property string markScript: Qt.resolvedUrl("mark-seen").toString().replace(/^file:\/\//, "")

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
  // Every Request, newest first; the agent answers them in its next session.
  property var requests: []
  readonly property int waitingCount: requests.filter(function(r) { return r.state === "waiting" }).length
  // The node's state as `relay-events` reports it; null when there is no agent
  // node. Each group in it is null when its command failed.
  property var nodeState: null
  // The Node section's cursor.
  property int nodeCursor: 0

  // True while the panel is open. Opening it records that the Observer looked
  // (the `mark-seen` script, which keeps the time on disk, so it holds across
  // restarts and is the same on every monitor).
  property bool looking: false
  // "none", "news" or "urgent", as relay-events reports it.
  property string attention: "none"
  readonly property bool hasUnseen: loaded && attention === "news"
  readonly property bool urgent: loaded && attention === "urgent"
  // Set when the Observer looks while a refresh is running: that refresh read
  // the time of the look before, so its "news" is already seen.
  property bool lookedDuringFetch: false

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
  // What Network shows: a thread (the id of the event it was opened on), an
  // author page (a pubkey), or, while both are empty, the feed.
  property string threadId: ""
  property string profilePubkey: ""
  // The views Esc comes back to, oldest first, each { profile, thread, cursor };
  // empty while the feed shows, else the first is the feed.
  property var trail: []

  onLookingChanged: if (looking) markSeen()

  function markSeen() {
    if (attention === "news") attention = "none"
    if (fetchProc.running) lookedDuringFetch = true
    if (!markProc.running) markProc.running = true
  }

  // Asked for while a fetch runs, another follows it, so it sees what changed since.
  property bool refreshAgain: false
  function refresh() {
    if (fetchProc.running) { refreshAgain = true; return }
    lookedDuringFetch = false
    fetchProc.running = true
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
    var reqs = report.requests || []
    reqs.sort(function(a, b) { return b.created_at - a.created_at })
    root.requestCursor = indexAfter(root.requests, reqs, root.requestCursor)
    root.requests = reqs
    root.nodeState = report.state && typeof report.state === "object" ? report.state : null
    root.online = report.online === true
    root.relayName = report.name || ""
    root.loaded = true
    root.attention = report.attention === "urgent" || (report.attention === "news" && !root.lookedDuringFetch)
      ? report.attention : "none"
    // Nothing is "new" before the Observer has ever looked, nor while the panel is showing it.
    if (report.looked_at === null || root.looking) root.markSeen()
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
    // A Request's outcome: what the agent published, or the Request and its reason.
    if (entry.request) {
      if (entry.refers_to && openEvent(entry.refers_to)) return
      requestCursor = Math.max(0, requests.map(function(r) { return r.id }).indexOf(entry.request.id))
      section = requestsSection
      return
    }
    var target = (entry.refers_to ? eventById(entry.refers_to) : null) || entry
    openThread(target.id)
  }

  // Opens the thread of an event in the Network; false if the relay does not hold it.
  function openEvent(id) {
    if (!eventById(id)) return false
    openThread(id)
    return true
  }

  // Writes a Request, or withdraws a waiting one. The text goes to the script
  // as an argument, never through a shell.
  property var pendingCommands: []
  function submitRequest(text) {
    if (String(text).trim() === "") return
    runRequest([requestScript, "add", "--", String(text)])
  }
  // A Request about a thing on screen: kind is follow, unfollow, reply, react
  // or repost; the text is optional. The subject goes as arguments too.
  function submitAbout(kind, pubkey, event, text) {
    var command = [requestScript, "add", "--kind", String(kind)]
    if (pubkey) command.push("--pubkey", String(pubkey))
    if (event) command.push("--event", String(event))
    command.push("--", String(text || "").trim())
    runRequest(command)
  }
  // The agent follows this author, as its own follow list says.
  function followsAuthor(pubkey) {
    return selfPubkey !== "" && (followMap[selfPubkey] || []).indexOf(pubkey) !== -1
  }
  // Waiting Requests of a kind about an author (pubkey) or a note (event).
  function waitingAbout(kind, pubkey, event) {
    return requests.filter(function(r) {
      var subject = r.subject || {}
      return r.state === "waiting" && r.kind === kind
        && (event ? subject.event === event : (!subject.event && subject.pubkey === pubkey))
    })
  }
  // The kinds still waiting on this author or note, for showing next to it.
  function waitingKinds(pubkey, event) {
    var kinds = event ? ["reply", "react", "repost"] : ["follow", "unfollow"]
    return kinds.filter(function(k) { return waitingAbout(k, pubkey, event).length > 0 })
  }
  // Opens the note or author a Request is about; false if there is nothing to open.
  function openSubject(request) {
    var subject = request.subject || {}
    if (subject.event && openEvent(subject.event)) return true
    if (subject.pubkey) { openAuthor(subject.pubkey); return true }
    return false
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

  Process {
    id: markProc
    command: [root.markScript]
  }

  Timer {
    interval: root.refreshSeconds * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
