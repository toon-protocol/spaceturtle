import QtQuick
import Quickshell.Widgets
import qs.Commons

// Round profile picture. Falls back to the name's first letter on a tinted
// disc while the picture loads, or when the profile has none.
Item {
  id: root

  property string source: ""
  property string label: ""
  property real size: Style.space(28)
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  width: size
  height: size
  implicitWidth: size
  implicitHeight: size

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: Qt.alpha(Color.accent, 0.22)
    visible: picture.status !== Image.Ready

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: root.label.slice(0, 1).toUpperCase()
      color: Color.accent
      font.family: root.fontFamily
      font.pixelSize: Math.round(root.size * 0.45)
      font.bold: true
    }
  }

  ClippingRectangle {
    anchors.fill: parent
    radius: width / 2
    color: "transparent"
    visible: picture.status === Image.Ready

    Image {
      id: picture
      anchors.fill: parent
      // Only web pictures: a profile is untrusted and must not name a local file.
      source: /^https?:\/\//.test(root.source) ? root.source : ""
      asynchronous: true
      cache: true
      fillMode: Image.PreserveAspectCrop
      sourceSize.width: Math.round(root.size * 2)
      sourceSize.height: Math.round(root.size * 2)
    }
  }

  // Hairline ring, so a picture on the popup's own background still reads as a disc.
  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: "transparent"
    border.width: 1
    border.color: Qt.alpha(root.foreground, 0.25)
  }
}
