import QtQuick
import qs.Commons
import qs.Ui

// The Activity section, where the panel opens: when the agent was last active,
// and what it did, newest first. Enter or a click opens the event an entry
// refers to on its author's page in the Network. Where the cursor is lives on
// the service.
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

  // An event's parts are resolved by relay-events; nothing here looks at a kind.
  function partsOf(event) { return event.parts || ({}) }

  function verbOf(event) {
    if (event.request) return event.request.state === "done" ? "Request done" : "Request declined"
    var label = String(partsOf(event).label || "")
    if (label) return label.charAt(0).toUpperCase() + label.slice(1)
    return event.refers_to ? "Replied" : "Posted"
  }

  function bodyOf(event) {
    if (event.request) {
      var reason = event.request.reason ? "\n" + event.request.reason : ""
      return String(event.request.text) + reason
    }
    var parts = partsOf(event)
    return String(parts.title || parts.summary || parts.body || "").trim()
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

          hasCursor: root.cursor === index
          width: parent ? parent.width : 0
          height: entry.implicitHeight + Style.spacing.lg * 2

          onHasCursorChanged: if (hasCursor && root.scrollOnCursor) root.ensureVisible(row)

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
                text: root.ago(row.modelData.created_at)
                color: root.dim
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
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: function(mouse) {
              if (!pointerGate.moved(row, mouse)) return
              root.scrollOnCursor = false
              root.service.activityCursor = row.index
            }
            onClicked: {
              root.service.activityCursor = row.index
              root.activate()
            }
          }
        }
      }
    }
  }
}
