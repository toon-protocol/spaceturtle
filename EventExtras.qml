import QtQuick
import qs.Commons

// What a Renderer description lays out beside an event's text: a badge,
// labelled fields, a list, a progress bar and actions. Every value is the
// event's own, shown as plain text. An action does nothing here: a click asks
// for its Request to be written, and it is the agent that acts.
Column {
  id: root

  // The event's parts, as relay-events resolved them.
  property var parts: ({})
  // Actions are offered only where a Request can be written.
  property bool offersActions: false
  property color dim: Qt.darker(Color.foreground, 1.5)

  readonly property string badge: String(parts.badge || "")
  readonly property var fields: parts.fields || []
  readonly property var items: parts.items || []
  readonly property var progress: parts.progress || null
  readonly property var actions: offersActions ? (parts.actions || []) : []

  // An action was chosen: {label, request}.
  signal acted(var action)

  spacing: Style.space(4)
  visible: badge !== "" || fields.length > 0 || items.length > 0 || progress !== null || actions.length > 0

  Rectangle {
    visible: root.badge !== ""
    width: badgeText.implicitWidth + Style.space(12)
    height: badgeText.implicitHeight + Style.space(4)
    radius: Math.min(4, Style.cornerRadius)
    color: Qt.alpha(Color.accent, 0.18)

    Text {
      id: badgeText
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: root.badge.slice(0, 24)
      color: Color.accent
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  Repeater {
    model: root.fields

    Row {
      required property var modelData
      width: root.width
      spacing: Style.space(8)

      Text {
        id: fieldLabel
        textFormat: Text.PlainText
        text: String(parent.modelData.label).toUpperCase()
        color: root.dim
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.letterSpacing: 1
        anchors.baseline: fieldValue.baseline
      }
      Text {
        id: fieldValue
        textFormat: Text.PlainText
        width: parent.width - fieldLabel.width - parent.spacing
        text: String(parent.modelData.value)
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }
    }
  }

  Repeater {
    model: root.items

    Text {
      required property string modelData
      textFormat: Text.PlainText
      width: root.width
      wrapMode: Text.Wrap
      maximumLineCount: 2
      elide: Text.ElideRight
      text: "•  " + modelData
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
  }

  Row {
    visible: root.progress !== null
    width: root.width
    spacing: Style.space(8)

    Rectangle {
      id: track
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - amount.implicitWidth - parent.spacing
      height: Style.space(6)
      radius: height / 2
      color: Qt.alpha(Color.accent, 0.18)

      Rectangle {
        height: parent.height
        radius: parent.radius
        width: root.progress ? parent.width * Math.max(0, Math.min(1, root.progress.value / root.progress.max)) : 0
        color: Color.accent
      }
    }
    Text {
      id: amount
      textFormat: Text.PlainText
      text: root.progress ? root.progress.value + " / " + root.progress.max : ""
      color: root.dim
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }

  Flow {
    visible: root.actions.length > 0
    width: root.width
    spacing: Style.space(6)
    topPadding: Style.space(2)

    Repeater {
      model: root.actions

      Rectangle {
        required property var modelData
        required property int index
        width: actionText.implicitWidth + Style.space(16)
        height: actionText.implicitHeight + Style.space(8)
        radius: Math.min(4, Style.cornerRadius)
        color: "transparent"
        border.color: Color.accent
        border.width: 1

        Text {
          id: actionText
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: (parent.index === 0 ? "g  " : "") + String(parent.modelData.label)
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.acted(parent.modelData)
        }
      }
    }
  }
}
