import QtQuick
import qs.Commons
import qs.Ui

// The Messages section: the agent identity's private messages, as the
// supervisor opened them. First the conversations, newest first; Enter or a
// click opens one and shows its messages, oldest first. The Observer only
// reads: a reply is the agent's to send, asked for with a Request. Which
// conversation shows and where the cursor is live on the service.
Item {
  id: root

  required property var service

  readonly property color dim: Qt.darker(Color.foreground, 1.5)

  // The conversation showing, or null while the list of them shows.
  readonly property var conversation: service.conversationById(service.conversationId)
  readonly property var rows: conversation ? conversation.messages : service.conversations
  readonly property int cursor: Math.max(0, Math.min(service.messageCursor, rows.length - 1))
  property bool scrollOnCursor: true

  readonly property string statusText: {
    if (!service.loaded) return "Loading…"
    if (!service.messagesReadable) return lockedText(service.messagesReason)
    var stopped = service.messagesSupervisor ? "" : "\nThe supervisor is not running, so no new message is opened."
    if (conversation) {
      var subject = conversation.subject ? "\n" + conversation.subject : ""
      return "With " + namesOf(conversation) + subject + stopped
    }
    var count = service.conversations.length
    if (count === 0) return "No private messages yet." + stopped
    return count + " conversation" + (count === 1 ? "" : "s") + stopped
  }

  // Why the private messages cannot be read, as relay-events reports it.
  function lockedText(reason) {
    if (reason === "unsupported")
      return "Private messages are locked: this toon cannot list them. Update toon to a version that has `toon message list`."
    if (reason === "agent_key_not_kept")
      return "Private messages are locked: the agent node does not keep the agent identity's secret yet. It does once the agent publishes an event or sends a message."
    return "Private messages could not be read."
  }

  function namesOf(conversation) {
    return (conversation.participants || []).map(function(key) { return service.nameOf(key) }).join(", ")
  }

  function lastOf(conversation) {
    var messages = conversation.messages || []
    return messages.length > 0 ? messages[messages.length - 1] : null
  }

  function bodyOf(message) {
    if (!message) return ""
    return (message.file === true ? "File: " : "") + String(message.body || "").trim()
  }

  function move(dy) {
    pointerGate.reset()
    root.scrollOnCursor = true
    service.messageCursor = Math.max(0, Math.min(root.cursor + dy, rows.length - 1))
    if (service.messageCursor === 0) scroll.contentY = 0
  }

  // A conversation opens; in one, a message opens its author's page.
  function activate() {
    if (rows.length === 0) return
    if (conversation) service.openAuthor(rows[root.cursor].from)
    else service.openConversation(rows[root.cursor].id)
  }

  // Esc: back to the conversations. False when they are showing.
  function back() { return service.closeConversation() }

  // `a` opens the author's page: of the message, or of whom the conversation is with.
  function key(text) {
    if (text !== "a" || rows.length === 0) return
    var row = rows[root.cursor]
    service.openAuthor(conversation ? row.from : (row.participants || [])[0])
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
        text: root.statusText
        color: root.rows.length > 0 ? Color.foreground : root.dim
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.italic: root.rows.length === 0
      }

      PanelSeparator {}

      Repeater {
        model: root.rows

        CursorSurface {
          id: row
          required property var modelData
          required property int index

          // In the list a row is a conversation, shown by its last message.
          readonly property bool listed: root.conversation === null
          readonly property var message: listed ? root.lastOf(modelData) : modelData
          readonly property string pictureOf: listed ? ((modelData.participants || [])[0] || "") : modelData.from

          hasCursor: root.cursor === index
          width: parent ? parent.width : 0
          height: Math.max(avatar.height, entry.implicitHeight) + Style.spacing.lg * 2

          onHasCursorChanged: if (hasCursor && root.scrollOnCursor) root.ensureVisible(row)
          // A conversation opens with the cursor on its last message, which is below the fold.
          Component.onCompleted: if (hasCursor) Qt.callLater(root.ensureVisible, row)

          Avatar {
            id: avatar
            size: Style.space(28)
            source: root.service.field(row.pictureOf, "picture")
            label: root.service.nameOf(row.pictureOf)
            anchors.left: parent.left
            anchors.leftMargin: Style.spacing.lg
            anchors.top: parent.top
            anchors.topMargin: Style.spacing.lg
          }

          Column {
            id: entry
            anchors.left: avatar.right
            anchors.leftMargin: Style.space(10)
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.lg
            anchors.top: parent.top
            anchors.topMargin: Style.spacing.lg
            spacing: Style.space(3)

            Row {
              spacing: Style.space(8)
              Text {
                textFormat: Text.PlainText
                text: row.listed ? root.namesOf(row.modelData) : root.service.nameOf(row.modelData.from)
                // What the agent sent stands out from what it received.
                color: !row.listed && row.modelData.sent === true ? Color.accent : Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
              Text {
                textFormat: Text.PlainText
                text: row.message ? root.ago(row.message.created_at) : ""
                color: root.dim
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
              Text {
                visible: row.listed
                textFormat: Text.PlainText
                text: row.listed ? (row.modelData.messages || []).length + " message" + ((row.modelData.messages || []).length === 1 ? "" : "s") : ""
                color: root.dim
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            Text {
              visible: row.listed && text !== ""
              textFormat: Text.PlainText
              width: parent.width
              text: row.listed ? String(row.modelData.subject || "") : ""
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.italic: true
              elide: Text.ElideRight
            }

            Text {
              visible: text !== ""
              textFormat: Text.PlainText
              width: parent.width
              // The list names who wrote the last message; a message is shown in full.
              text: (row.listed && row.message ? root.service.nameOf(row.message.from) + ": " : "") + root.bodyOf(row.message)
              color: row.listed ? root.dim : Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              wrapMode: Text.Wrap
              maximumLineCount: row.listed ? 2 : 1000
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
              root.service.messageCursor = row.index
            }
            onClicked: {
              root.service.messageCursor = row.index
              root.activate()
            }
          }
        }
      }
    }
  }
}
