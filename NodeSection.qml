import QtQuick
import qs.Commons
import qs.Ui

// The Node section: the agent node's state, read with free `toon` commands, in
// groups. One cursor runs down every row; Enter or a click copies the row's
// value. Where it is lives on the service, so it survives the panel closing.
Item {
  id: root

  required property var service

  readonly property color dim: Qt.darker(Color.foreground, 1.5)

  readonly property var node: service.nodeState
  readonly property string balancesText: "not shown: needs the passphrase"

  function yesNo(value) { return value === null || value === undefined ? "unknown" : (value ? "running" : "stopped") }
  function plural(n, one, many) { return n + " " + (n === 1 ? one : many) }
  function process(p) { return yesNo(p.running) + ", " + plural(p.restarts, "restart", "restarts") }
  // The parts that are not empty, joined.
  function joined(parts) { return parts.filter(function(x) { return x !== "" }).join(", ") }

  // Rows: { group } starts a group; { label, value, note } is a row the cursor
  // can stand on. `note` marks a group that could not be read.
  readonly property var rows: {
    var list = []
    var st = node
    if (!st) return list
    var current = ""
    function group(name) { current = name; list.push({ group: name }) }
    function row(label, value) { list.push({ label: label, value: String(value), under: current }) }
    function unavailable() { list.push({ label: "", value: "unavailable", note: true, under: current }) }
    function none() { list.push({ label: "", value: "none", note: true, under: current }) }

    group("Processes")
    if (!st.status) unavailable()
    else {
      row("Supervisor", process(st.status.supervisor))
      row("Connector", process(st.status.connector))
      for (var a = 0; a < st.status.apps.length; a++) row(st.status.apps[a].name, process(st.status.apps[a]))
    }

    group("Relay")
    if (!st.relay) unavailable()
    else {
      row("Name", st.relay.name || "–")
      for (var p = 0; p < st.relay.prices.length; p++) row("Price " + st.relay.prices[p].name, st.relay.prices[p].price)
      row("Blocklist", st.relay.blocklist.length === 0 ? "empty" : plural(st.relay.blocklist.length, "entry", "entries"))
      for (var b = 0; b < st.relay.blocklist.length; b++) row("Blocked", st.relay.blocklist[b])
    }

    group("Peerings")
    if (!st.peers) unavailable()
    else if (st.peers.length === 0) none()
    else for (var i = 0; i < st.peers.length; i++)
      row(st.peers[i].id, joined([st.peers[i].direction, st.peers[i].status]))

    group("Channels")
    if (!st.channels) unavailable()
    else if (st.channels.length === 0) none()
    else for (var c = 0; c < st.channels.length; c++) {
      var ch = st.channels[c]
      row(ch.peer, joined([ch.direction, ch.status, ch.collateral !== "" ? "collateral " + ch.collateral : ""]))
    }

    group("Routes")
    if (!st.routes) unavailable()
    else if (st.routes.length === 0) none()
    else for (var r = 0; r < st.routes.length; r++)
      row(st.routes[r].prefix, joined([st.routes[r].peer, st.routes[r].price !== "" ? "price " + st.routes[r].price : ""]))

    group("Spending limit")
    if (!st.limits) unavailable()
    else {
      row("Per command", st.limits.per_command || "–")
      row("Per day", st.limits.per_day || "–")
      row("Left today", st.limits.remaining_today || "–")
    }

    group("Subscriptions")
    if (!st.subscriptions) unavailable()
    else {
      var held = st.subscriptions.held
      row("Held", held === null ? "unavailable" : (held.length === 0 ? "none" : plural(held.length, "subscription", "subscriptions")))
      if (held) for (var h = 0; h < held.length; h++) row("", held[h])
      row("To your relay", st.subscriptions.incoming === null ? "–" : String(st.subscriptions.incoming))
    }

    group("Addresses")
    row("ILP", service.nodeIlp || "–")
    row("Connector", service.nodeConnector || "–")

    group("Wallet")
    list.push({ label: "Balances", value: balancesText, note: true })

    group("Log")
    if (!st.logs) unavailable()
    else if (st.logs.length === 0) none()
    else for (var l = 0; l < st.logs.length; l++) row("", st.logs[l])
    return list
  }

  // The cursor's targets are the rows that are not group headings.
  readonly property var targets: {
    var list = []
    for (var i = 0; i < rows.length; i++) if (rows[i].group === undefined) list.push(i)
    return list
  }
  readonly property int cursor: Math.max(0, Math.min(service.nodeCursor, targets.length - 1))
  property bool scrollOnCursor: true
  // The row whose value was just copied, for its "copied" flash; -1 for none.
  property int copiedIndex: -1

  function move(dy) {
    pointerGate.reset()
    root.scrollOnCursor = true
    service.nodeCursor = Math.max(0, Math.min(root.cursor + dy, root.targets.length - 1))
    if (service.nodeCursor === 0) scroll.contentY = 0
  }

  // Stand on the item an Activity entry concerns: its row in its group, or the
  // group's first row when the item is gone (a channel that closed). Before the
  // rows are in, the focus waits for them.
  function focusOn(focus) {
    if (!focus || root.targets.length === 0) return
    var first = -1
    for (var t = 0; t < root.targets.length; t++) {
      var r = root.rows[root.targets[t]]
      if (r.under !== focus.group) continue
      if (first < 0) first = t
      if (r.label === focus.label) { first = t; break }
    }
    service.nodeFocus = null
    root.scrollOnCursor = true
    service.nodeCursor = first < 0 ? 0 : first
    if (service.nodeCursor === 0) scroll.contentY = 0
  }

  Connections {
    target: root.service
    function onNodeFocusChanged() { root.focusOn(root.service.nodeFocus) }
  }
  onTargetsChanged: focusOn(service.nodeFocus)
  Component.onCompleted: focusOn(service.nodeFocus)

  function hover(target) {
    root.scrollOnCursor = false
    service.nodeCursor = target
  }

  // Enter: copy the value under the cursor. Notes ("unavailable", "not shown") are not values.
  function activate() {
    if (root.targets.length === 0) return
    var row = root.rows[root.targets[root.cursor]]
    if (row.note || row.value === "" || row.value === "–") return
    service.copy(row.value)
    root.copiedIndex = root.targets[root.cursor]
    copiedTimer.restart()
  }

  // Nothing below the top level: Esc closes the panel.
  function back() { return false }

  function key(text) {}

  function ensureVisible(item) {
    if (!item) return
    var top = item.mapToItem(column, 0, 0).y
    var bottom = top + item.height
    var margin = Style.space(12)
    if (top < scroll.contentY + margin) scroll.contentY = Math.max(0, top - margin)
    else if (bottom > scroll.contentY + scroll.height - margin)
      scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height, bottom + margin - scroll.height))
  }

  PointerMoveGate {
    id: pointerGate
    referenceItem: root
  }

  Timer {
    id: copiedTimer
    interval: 1500
    onTriggered: root.copiedIndex = -1
  }

  // No agent node: say so, and how to start one.
  Text {
    visible: !root.node
    anchors.centerIn: parent
    width: parent.width
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
    text: !root.service.loaded ? "Loading…" : "No agent node is running. Start one with: toon up"
    color: root.dim
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.italic: true
  }

  Flickable {
    id: scroll
    visible: !!root.node
    anchors.fill: parent
    contentWidth: width
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    Column {
      id: column
      width: scroll.width

      Repeater {
        model: root.rows

        Item {
          id: entry
          required property var modelData
          required property int index
          readonly property bool heading: modelData.group !== undefined
          readonly property int target: root.targets.indexOf(index)

          width: parent ? parent.width : 0
          height: heading ? headingText.implicitHeight + Style.space(16) : rowSurface.height

          Text {
            id: headingText
            visible: entry.heading
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.leftMargin: Style.spacing.lg
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(4)
            text: entry.heading ? entry.modelData.group.toUpperCase() : ""
            color: root.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
          }

          CursorSurface {
            id: rowSurface
            visible: !entry.heading
            hasCursor: !entry.heading && root.cursor === entry.target
            width: parent.width
            height: Math.max(valueText.implicitHeight, labelText.implicitHeight) + Style.spacing.sm * 2

            onHasCursorChanged: if (hasCursor && root.scrollOnCursor) root.ensureVisible(entry)

            Text {
              id: labelText
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.leftMargin: Style.spacing.lg
              anchors.baseline: valueText.baseline
              width: Style.space(120)
              elide: Text.ElideRight
              text: entry.heading ? "" : entry.modelData.label
              color: root.dim
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              id: valueText
              textFormat: Text.PlainText
              anchors.left: labelText.right
              anchors.right: parent.right
              anchors.rightMargin: Style.spacing.lg
              anchors.verticalCenter: parent.verticalCenter
              wrapMode: Text.Wrap
              text: entry.heading ? "" : (root.copiedIndex === entry.index ? "copied" : entry.modelData.value)
              color: root.copiedIndex === entry.index ? Color.accent : (!entry.heading && entry.modelData.note ? root.dim : Color.foreground)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.italic: !entry.heading && entry.modelData.note === true
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onPositionChanged: function(mouse) { if (pointerGate.moved(rowSurface, mouse)) root.hover(entry.target) }
              onClicked: {
                root.hover(entry.target)
                root.activate()
              }
            }
          }
        }
      }
    }
  }
}
