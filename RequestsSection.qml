import QtQuick
import qs.Commons
import qs.Ui

// The Requests section: ask the agent for something in your own words, and see
// where each Request stands. Requests are only written here; the agent answers
// them in its next session. A done one opens what the agent published, a
// declined one shows the agent's reason. Where the cursor is lives on the service.
Item {
  id: root

  required property var service

  readonly property color dim: Qt.darker(Color.foreground, 1.5)

  readonly property var requests: service.requests
  readonly property int cursor: Math.max(0, Math.min(service.requestCursor, requests.length - 1))
  property bool scrollOnCursor: true
  // Shown briefly when a done Request's event is not on the relay.
  property bool missing: false

  // The text box has the keys while it has focus; the panel is asked to take them back.
  readonly property bool typing: input.activeFocus
  signal leaveInput()

  readonly property string statusText: {
    if (!service.loaded) return "Loading…"
    var n = service.waitingCount
    var waiting = n === 0 ? "No Requests are waiting." : (n === 1 ? "1 Request is waiting." : n + " Requests are waiting.")
    var when = service.lastActive > 0 ? " Your agent was last active " + ago(service.lastActive) + "." : ""
    return waiting + " Your agent answers them in its next session." + when
  }

  function submit() {
    if (input.text.trim() === "") return
    service.submitRequest(input.text)
    input.text = ""
  }

  function move(dy) {
    pointerGate.reset()
    root.scrollOnCursor = true
    service.requestCursor = Math.max(0, Math.min(root.cursor + dy, requests.length - 1))
    if (service.requestCursor === 0) scroll.contentY = 0
  }

  // What a Request about a thing is about, in words.
  function subjectText(request) {
    var subject = request.subject || {}
    var verbs = { follow: "Follow", unfollow: "Unfollow", reply: "Reply to", react: "React to", repost: "Repost" }
    if (!verbs[request.kind]) return ""
    if (subject.event) return verbs[request.kind] + " note " + String(subject.event).slice(0, 8)
      + (subject.pubkey ? " by " + service.nameOf(subject.pubkey) : "")
    if (subject.pubkey) return verbs[request.kind] + " " + service.nameOf(subject.pubkey)
    return ""
  }

  // Enter: a done Request opens what the agent published; otherwise a Request
  // about a note or an author opens that.
  function activate() {
    root.missing = false
    if (requests.length === 0) return
    var request = requests[root.cursor]
    var id = request.result && typeof request.result.event === "string" ? request.result.event : ""
    if (request.state === "done" && id !== "") {
      if (!service.openEvent(id)) root.missing = true
    } else if (subjectText(request) !== "" && !service.openSubject(request)) root.missing = true
  }

  function back() { return false }

  // i writes a new Request; x withdraws the waiting one under the cursor.
  function key(text) {
    if (text === "i") input.forceActiveFocus()
    else if (text === "x" && requests.length > 0 && requests[root.cursor].state === "waiting")
      service.withdrawRequest(requests[root.cursor].id)
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

  function stateText(request) {
    if (request.state === "done") return "Done"
    if (request.state === "declined") return "Declined"
    return "Waiting"
  }

  PointerMoveGate {
    id: pointerGate
    referenceItem: root
  }

  Timer {
    id: clock
    property real now: Date.now()
    interval: 30000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: now = Date.now()
  }

  Column {
    id: top
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: Style.spacing.sm

    Text {
      width: parent.width
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      text: root.statusText
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }

    Rectangle {
      width: parent.width
      height: input.implicitHeight + Style.spacing.lg * 2
      color: "transparent"
      radius: Math.min(4, Style.cornerRadius)
      border.width: 1
      border.color: input.activeFocus ? Color.accent : root.dim
      // Whatever the text box does not use stops here, so the panel never sees it.
      Keys.onPressed: function(event) { event.accepted = true }

      TextInput {
        id: input
        anchors.fill: parent
        anchors.margins: Style.spacing.lg
        color: Color.foreground
        selectionColor: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        clip: true
        // Enter sends; Esc, Tab and the arrows hand the keys back to the panel.
        // Every other key is typed, and the panel never sees it.
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.submit()
            event.accepted = true
          } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab
                     || event.key === Qt.Key_Backtab || event.key === Qt.Key_Up
                     || event.key === Qt.Key_Down) {
            root.leaveInput()
            event.accepted = true
          }
        }

        Text {
          visible: input.text === "" && !input.activeFocus
          text: "Ask your agent for something… (i to write)"
          color: root.dim
          font: input.font
        }
        Text {
          visible: input.text === "" && input.activeFocus
          text: "Enter sends, Esc leaves"
          color: root.dim
          font: input.font
        }
      }
    }

    Text {
      visible: root.missing
      width: parent.width
      textFormat: Text.PlainText
      text: "The relay does not hold that."
      color: root.dim
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.italic: true
    }

    PanelSeparator {}
  }

  Flickable {
    id: scroll
    anchors.top: top.bottom
    anchors.topMargin: Style.spacing.sm
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    contentWidth: width
    contentHeight: column.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: column
      width: parent.width
      spacing: Style.spacing.sm

      Repeater {
        model: root.requests

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
                text: root.stateText(row.modelData)
                color: row.modelData.state === "waiting" ? root.dim : Color.accent
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
              text: root.subjectText(row.modelData)
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            Text {
              visible: text !== ""
              textFormat: Text.PlainText
              width: parent.width
              text: String(row.modelData.text)
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              wrapMode: Text.Wrap
              maximumLineCount: 4
              elide: Text.ElideRight
            }

            Text {
              visible: row.modelData.state === "declined"
              textFormat: Text.PlainText
              width: parent.width
              text: row.modelData.reason ? String(row.modelData.reason) : "No reason given."
              color: root.dim
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.italic: true
              wrapMode: Text.Wrap
            }

            Text {
              visible: row.modelData.state === "done" || root.subjectText(row.modelData) !== ""
              textFormat: Text.PlainText
              width: parent.width
              text: row.modelData.state === "done" ? "Enter opens what the agent published" : "Enter opens it"
              color: root.dim
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            Text {
              visible: row.modelData.state === "waiting" && row.hasCursor
              textFormat: Text.PlainText
              width: parent.width
              text: "x withdraws it"
              color: root.dim
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: function(mouse) {
              if (!pointerGate.moved(row, mouse)) return
              root.scrollOnCursor = false
              root.service.requestCursor = row.index
            }
            onClicked: {
              root.service.requestCursor = row.index
              root.activate()
            }
          }
        }
      }
    }
  }
}
