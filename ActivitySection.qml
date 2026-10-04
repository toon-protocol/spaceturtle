import QtQuick
import qs.Commons
import qs.Ui

// The Activity section, where the panel opens: when the agent was last active,
// and what it did, newest first. Enter or a click opens the thread of the event
// an entry refers to in the Network; `y`, `c` or a right click copies the
// entry's text, `u` or a click on a picture its address. Where the cursor is
// lives on the service.
Item {
  id: root

  required property var service

  readonly property color dim: Qt.darker(Color.foreground, 1.5)

  readonly property bool known: service.selfPubkey !== ""
  readonly property int cursor: Math.max(0, Math.min(service.activityCursor, service.activity.length - 1))
  property bool scrollOnCursor: true

  readonly property string lastActiveText: {
    if (!service.loaded) return "Loading…"
    if (!service.online) return "The relay is not running."
    if (!known) return "The agent is not yet known."
    if (service.lastActive <= 0) return "The agent has not been active yet."
    return "Last active " + ago(service.lastActive)
  }

  function move(dy) {
    pointerGate.reset()
    root.scrollOnCursor = true
    service.activityCursor = Math.max(0, Math.min(root.cursor + dy, service.activity.length - 1))
    if (service.activityCursor === 0) scroll.contentY = 0
  }

  function activate() {
    if (service.activity.length > 0) service.openActivity(service.activity[root.cursor])
  }

  // Nothing to go back to: the panel closes.
  function back() { return false }
  // `a` opens the agent's own page; `y` or `c` copies the entry under the
  // cursor, `u` the address of its first picture, video or sound; `p` plays or
  // pauses its video or sound.
  function key(text) {
    var entry = service.activity.length > 0 ? service.activity[root.cursor] : null
    if (text === "a" && known) service.openAuthor(service.selfPubkey)
    else if ((text === "y" || text === "c") && entry) copy(entry)
    else if (text === "u" && entry) copyValue(entry, service.firstMedia(entry))
    else if (text === "p" && root.cursorMedia) root.cursorMedia.toggle()
    else if (text === "g" && entry && (partsOf(entry).actions || []).length > 0) service.askAbout(entry, partsOf(entry).actions[0])
  }

  // The media of the entry under the cursor, for `p`.
  property var cursorMedia: null

  // The id of the entry whose text was just copied, for its "copied" flash.
  property string copiedId: ""

  function copy(event) { copyValue(event, textOf(event)) }

  function copyValue(event, value) {
    if (value === "") return
    service.copy(value)
    root.copiedId = String(event.id)
    copiedTimer.restart()
  }

  function ensureVisible(item) {
    if (!item) return
    var top = item.mapToItem(column, 0, 0).y
    var bottom = top + item.height
    var margin = Style.space(12)
    if (top < scroll.contentY + margin) scroll.contentY = Math.max(0, top - margin)
    else if (bottom > scroll.contentY + scroll.height - margin)
      scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height, bottom + margin - scroll.height))
  }

  // An event's parts are resolved by relay-events; nothing here looks at a kind.
  function partsOf(event) { return event.parts || ({}) }

  function verbOf(event) {
    if (event.node_change === true) return "Node"
    if (event.request) return event.request.state === "done" ? "Request done" : "Request declined"
    var label = String(partsOf(event).label || "")
    if (label) return label.charAt(0).toUpperCase() + label.slice(1)
    return event.refers_to ? "Replied" : "Posted"
  }

  function bodyOf(event) {
    if (event.node_change === true) return String(event.text || "")
    if (event.request) {
      var reason = event.request.reason ? "\n" + event.request.reason : ""
      return String(event.request.text) + reason
    }
    var parts = partsOf(event)
    // A picture shown under the text is not also named in it.
    return service.withoutMedia([parts.title, parts.summary, parts.body].filter(function(line) { return line }).join("\n"), parts.media)
  }

  // The whole of an entry's text, not cut to the lines its card shows.
  function textOf(event) {
    if (event.node_change === true || event.request) return bodyOf(event)
    var parts = partsOf(event)
    return [parts.title, parts.summary, parts.body].filter(function(line) { return line }).join("\n")
  }

  function ago(seconds) {
    var delta = Math.max(0, Math.floor(clock.now / 1000) - seconds)
    if (delta < 60) return "just now"
    var unit = delta < 3600 ? [60, "minute"] : (delta < 86400 ? [3600, "hour"] : [86400, "day"])
    var n = Math.floor(delta / unit[0])
    return n + " " + unit[1] + (n === 1 ? "" : "s") + " ago"
  }

  // Keeps a row that slides under a still pointer from taking the cursor.
  PointerMoveGate {
    id: pointerGate
    referenceItem: root
  }

  Timer {
    id: copiedTimer
    interval: 1500
    onTriggered: root.copiedId = ""
  }

  // Drives the relative timestamps.
  Timer {
    id: clock
    property real now: Date.now()
    interval: 30000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: now = Date.now()
  }

  Flickable {
    id: scroll
    anchors.fill: parent
    contentWidth: width
    contentHeight: column.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: column
      width: parent.width
      spacing: Style.spacing.sm

      Text {
        width: parent.width
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: root.lastActiveText
        color: root.service.lastActive > 0 ? Color.foreground : root.dim
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.italic: root.service.lastActive <= 0
      }

      PanelSeparator {}

      Repeater {
        model: root.service.activity

        CursorSurface {
          id: row
          required property var modelData
          required property int index

          readonly property bool justCopied: root.copiedId !== "" && root.copiedId === String(modelData.id)

          hasCursor: root.cursor === index
          width: parent ? parent.width : 0
          height: entry.implicitHeight + Style.spacing.lg * 2

          onHasCursorChanged: {
            if (hasCursor) root.cursorMedia = media
            if (hasCursor && root.scrollOnCursor) root.ensureVisible(row)
          }
          Component.onCompleted: if (hasCursor) root.cursorMedia = media
          Component.onDestruction: if (root.cursorMedia === media) root.cursorMedia = null

          // First, so that a picture sits above it.
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: function(mouse) {
              if (!pointerGate.moved(row, mouse)) return
              root.scrollOnCursor = false
              root.service.activityCursor = row.index
            }
            onClicked: function(mouse) {
              root.service.activityCursor = row.index
              if (mouse.button === Qt.RightButton) root.copy(row.modelData)
              else root.activate()
            }
          }

          Column {
            id: entry
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Style.spacing.lg
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(3)

            Row {
              spacing: Style.space(8)
              Text {
                textFormat: Text.PlainText
                text: root.verbOf(row.modelData)
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
              Text {
                textFormat: Text.PlainText
                // A node change is when it was noticed, not when it happened.
                text: row.justCopied ? "copied"
                  : (row.modelData.node_change === true ? "noticed " : "") + root.ago(row.modelData.created_at)
                color: row.justCopied ? Color.accent : root.dim
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            Text {
              visible: text !== ""
              textFormat: Text.PlainText
              width: parent.width
              text: root.bodyOf(row.modelData)
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              wrapMode: Text.Wrap
              maximumLineCount: 4
              elide: Text.ElideRight
            }

            EventExtras {
              width: parent.width
              parts: root.partsOf(row.modelData)
              offersActions: true
              dim: root.dim
              onActed: function(action) {
                root.service.activityCursor = row.index
                root.service.askAbout(row.modelData, action)
              }
            }

            MediaStrip {
              id: media
              width: parent.width
              sources: root.partsOf(row.modelData).media || []
              dim: root.dim
              onPicked: function(address) {
                root.service.activityCursor = row.index
                root.copyValue(row.modelData, address)
              }
            }
          }
        }
      }
    }
  }
}
