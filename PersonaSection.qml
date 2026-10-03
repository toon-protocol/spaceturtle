import QtQuick
import qs.Commons
import qs.Ui

// The Persona section: who this Install is. With no profile for the agent
// identity it asks "Who is this?": the Observer describes a Persona or leaves it
// to the agent, and either writes a `persona` Request. With one it shows the
// picture, name, character, followers and following. Writing a Request needs no
// passphrase and costs nothing; the agent publishes the profile in its next session.
Item {
  id: root

  required property var service

  readonly property color dim: Qt.darker(Color.foreground, 1.5)

  readonly property var persona: service.persona
  readonly property bool named: persona !== null
  readonly property int waiting: service.requests.filter(function(r) { return r.kind === "persona" && r.state === "waiting" }).length

  // The two things the Observer can do, in cursor order.
  readonly property var choices: [
    { id: "describe", label: named ? "Change the Persona…" : "Describe a Persona…", hint: "d" },
    { id: "agent", label: named ? "Leave a new Persona to the agent" : "Leave it to the agent", hint: "" }
  ]
  property int cursor: 0
  property bool describing: false

  // The text boxes have the keys while one has focus; the panel is asked to take them back.
  readonly property bool typing: nameInput.activeFocus || characterInput.activeFocus || pictureInput.activeFocus
  signal leaveInput()

  function move(dy) { cursor = Math.max(0, Math.min(cursor + dy, choices.length - 1)) }

  function activate() {
    if (choices[cursor].id === "describe") describe()
    else service.leavePersonaToAgent()
  }

  function describe() {
    nameInput.text = named ? persona.name : ""
    characterInput.text = named ? persona.character : ""
    pictureInput.text = named ? persona.picture : ""
    describing = true
    Qt.callLater(function() { nameInput.forceActiveFocus() })
  }

  function stopDescribing() {
    describing = false
    leaveInput()
  }

  function submit() {
    var any = nameInput.text.trim() !== "" || characterInput.text.trim() !== "" || pictureInput.text.trim() !== ""
    if (!any) return
    service.describePersona(nameInput.text, characterInput.text, pictureInput.text)
    stopDescribing()
  }

  // Esc leaves the form first.
  function back() {
    if (!describing) return false
    stopDescribing()
    return true
  }

  function key(text) { if (text === "d") describe() }

  function plural(n, one, many) { return n + " " + (n === 1 ? one : many) }

  component Field: Rectangle {
    id: field
    property alias input: box
    property string placeholder: ""
    signal next()
    width: parent ? parent.width : 0
    height: box.implicitHeight + Style.spacing.lg * 2
    color: "transparent"
    radius: Math.min(4, Style.cornerRadius)
    border.width: 1
    border.color: box.activeFocus ? Color.accent : root.dim
    Keys.onPressed: function(event) { event.accepted = true }

    TextInput {
      id: box
      anchors.fill: parent
      anchors.margins: Style.spacing.lg
      color: Color.foreground
      selectionColor: Color.accent
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      clip: true
      // Enter sends, Tab moves on, Esc leaves. Every other key is typed.
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.submit()
          event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
          field.next()
          event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
          root.stopDescribing()
          event.accepted = true
        }
      }

      Text {
        visible: box.text === ""
        text: field.placeholder
        color: root.dim
        font: box.font
      }
    }
  }

  Flickable {
    anchors.fill: parent
    contentWidth: width
    contentHeight: column.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: column
      width: parent.width
      spacing: Style.spacing.sm

      // ---------- Named: picture, name, character ----------
      Row {
        visible: root.named
        spacing: Style.space(12)

        Avatar {
          size: Style.space(64)
          source: root.named ? root.persona.picture : ""
          label: root.named ? root.persona.name : ""
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(3)

          Text {
            textFormat: Text.PlainText
            text: root.named ? root.persona.name : ""
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }
          Row {
            spacing: Style.space(18)
            Text {
              textFormat: Text.PlainText
              text: root.plural(root.named ? root.service.followerCount(root.service.selfPubkey) : 0, "follower", "followers")
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              textFormat: Text.PlainText
              text: (root.named ? root.service.followingCount(root.service.selfPubkey) : 0) + " following"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }

      Text {
        visible: root.named
        width: parent.width
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: root.named ? (root.persona.character !== "" ? root.persona.character : "No character yet.") : ""
        color: root.named && root.persona.character !== "" ? Color.foreground : root.dim
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.italic: root.named && root.persona.character === ""
      }

      // ---------- Unnamed: who is this? ----------
      Text {
        visible: !root.named
        width: parent.width
        textFormat: Text.PlainText
        text: !root.service.loaded ? "Loading…" : (root.service.selfPubkey === "" ? "Who is this? The agent is not yet known." : "Who is this?")
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Text {
        visible: !root.named
        width: parent.width
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: "This turtle has no name yet. Describe a name, a character and a picture, or leave it to the agent."
        color: root.dim
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        visible: root.waiting > 0
        width: parent.width
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: (root.waiting === 1 ? "A Persona Request is waiting." : root.waiting + " Persona Requests are waiting.") + " The agent publishes it in its next session."
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      PanelSeparator {}

      // ---------- The describe form ----------
      Column {
        visible: root.describing
        width: parent.width
        spacing: Style.spacing.sm

        Field { id: nameField; placeholder: "Name"; onNext: characterInput.forceActiveFocus() }
        Field { id: characterField; placeholder: "Character: how it speaks and behaves"; onNext: pictureInput.forceActiveFocus() }
        Field { id: pictureField; placeholder: "Picture: an http(s) address"; onNext: nameInput.forceActiveFocus() }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: "Enter sends, Tab moves on, Esc leaves"
          color: root.dim
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Repeater {
        model: root.describing ? [] : root.choices

        CursorSurface {
          id: row
          required property var modelData
          required property int index

          hasCursor: root.cursor === index
          width: parent ? parent.width : 0
          height: choice.implicitHeight + Style.spacing.lg * 2

          Text {
            id: choice
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Style.spacing.lg
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: row.modelData.label + (row.modelData.hint !== "" ? "  (" + row.modelData.hint + ")" : "")
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.cursor = row.index
              root.activate()
            }
          }
        }
      }
    }
  }

  readonly property alias nameInput: nameField.input
  readonly property alias characterInput: characterField.input
  readonly property alias pictureInput: pictureField.input
}
