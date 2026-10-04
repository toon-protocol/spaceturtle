import QtQuick
import Quickshell.Widgets
import qs.Commons

// The pictures of an event, one under the other, each fitted to the width and
// to `maxHeight`. A click on one asks for its address to be copied. A picture
// that is still loading takes no room; one that cannot load is named by its
// address, so that nothing the event carries goes unseen.
Column {
  id: root

  // The event's `media` part: relay-events resolved it, at most four addresses.
  property var sources: []
  property real maxHeight: Style.space(180)
  property color dim: Qt.darker(Color.foreground, 1.5)

  // A picture was clicked: `address` is where it came from.
  signal picked(string address)

  spacing: Style.space(6)
  visible: sources.length > 0

  Repeater {
    model: root.sources

    Item {
      id: slot
      required property string modelData
      // The bytes an event carries itself have no address to copy or to name.
      readonly property bool inline: /^data:/.test(modelData)
      readonly property real fit: picture.implicitWidth > 0 && picture.implicitHeight > 0
        ? Math.min(1, root.width / picture.implicitWidth, root.maxHeight / picture.implicitHeight) : 0
      readonly property bool ready: picture.status === Image.Ready
      readonly property bool failed: picture.status === Image.Error && !inline

      visible: ready || failed
      width: ready ? Math.round(picture.implicitWidth * fit) : root.width
      height: ready ? Math.round(picture.implicitHeight * fit) : address.implicitHeight

      ClippingRectangle {
        anchors.fill: parent
        visible: slot.ready
        radius: Math.min(4, Style.cornerRadius)
        color: "transparent"

        Image {
          id: picture
          anchors.fill: parent
          // Only web pictures, or the bytes relay-events took from the event itself:
          // an event is untrusted and must not name a local file.
          source: /^(https?:\/\/|data:image\/(png|jpeg|gif|webp);base64,)/.test(slot.modelData) ? slot.modelData : ""
          asynchronous: true
          cache: true
          fillMode: Image.PreserveAspectFit
          // Pixel art stays sharp: a picture is never scaled up, and not smoothed at its own size.
          smooth: slot.fit < 1
        }
      }

      Text {
        id: address
        visible: slot.failed
        textFormat: Text.PlainText
        width: parent.width
        wrapMode: Text.WrapAnywhere
        text: slot.modelData
        color: root.dim
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      MouseArea {
        anchors.fill: parent
        enabled: !slot.inline
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked(slot.modelData)
      }
    }
  }
}
