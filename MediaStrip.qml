import QtQuick
import QtMultimedia
import Quickshell.Widgets
import qs.Commons

// The media of an event, one under the other, each as wide as the card: a
// picture (animated if it moves), a video or a sound. A click on a picture, or
// a right click on any of them, asks for its address to be copied; a click on a
// video or a sound plays or pauses it, and nothing is fetched for either before
// that. A picture that is still loading takes no room; one that cannot load is
// named by its address, so that nothing the event carries goes unseen.
Column {
  id: root

  // The event's `media` part: relay-events resolved it, at most four, each
  // {url, type, moving}.
  property var sources: []
  // A tall picture is cropped to this; by default, to a square.
  property real maxHeight: width
  property color dim: Qt.darker(Color.foreground, 1.5)

  // The address of one of the media is to be copied.
  signal picked(string address)

  // Only the web, or the bytes relay-events took from the event itself: an
  // event is untrusted and must not name a local file.
  function allowed(address) { return /^(https?:\/\/|data:image\/(png|jpeg|gif|webp);base64,)/.test(address) }

  // Plays or pauses the first video or sound; false when there is none.
  function toggle() {
    for (var i = 0; i < slots.count; i++) {
      var slot = slots.itemAt(i)
      if (slot && slot.item && slot.item.toggle) { slot.item.toggle(); return true }
    }
    return false
  }

  spacing: Style.space(6)
  visible: sources.length > 0

  Repeater {
    id: slots
    model: root.sources

    Loader {
      id: slot
      required property var modelData
      readonly property string address: root.allowed(String(modelData.url || "")) ? String(modelData.url) : ""
      // The bytes an event carries itself have no address to copy or to name.
      readonly property bool inline: /^data:/.test(address)

      width: root.width
      visible: address !== "" && (!item || item.shown)
      sourceComponent: modelData.type === "video" ? video : (modelData.type === "audio" ? audio : picture)
    }
  }

  component Picture: Item {
    id: frame
    property bool moving: false
    property string address: ""
    property bool inline: false
    readonly property var image: loader.item
    readonly property bool ready: image !== null && image.status === Image.Ready
    readonly property bool failed: image !== null && image.status === Image.Error && !inline
    readonly property bool shown: ready || failed
    // As wide as the card, whatever its own size; cropped only if that makes it too tall.
    readonly property real natural: ready && image.implicitWidth > 0 ? width * image.implicitHeight / image.implicitWidth : 0

    width: parent ? parent.width : 0
    height: ready ? Math.round(Math.min(natural, root.maxHeight)) : name.implicitHeight

    ClippingRectangle {
      anchors.fill: parent
      visible: frame.ready
      radius: Math.min(4, Style.cornerRadius)
      color: "transparent"

      Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: frame.moving ? animated : still
      }
    }

    Component {
      id: still
      Image {
        source: frame.address
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        // Pixel art stays sharp when it is drawn much larger than it is.
        smooth: implicitWidth <= 0 || frame.width < implicitWidth * 2
      }
    }

    Component {
      id: animated
      AnimatedImage {
        source: frame.address
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        smooth: implicitWidth <= 0 || frame.width < implicitWidth * 2
        playing: frame.visible
      }
    }

    Text {
      id: name
      visible: frame.failed
      textFormat: Text.PlainText
      width: parent.width
      wrapMode: Text.WrapAnywhere
      text: frame.address
      color: root.dim
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }

    MouseArea {
      anchors.fill: parent
      enabled: !frame.inline
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: root.picked(frame.address)
    }
  }

  // A video or a sound: the player exists, and the address is fetched, only
  // once it has been asked to play.
  component Player: Item {
    id: player
    property string address: ""
    property bool pictured: false
    readonly property bool shown: true
    readonly property var media: loader.item
    readonly property bool playing: media !== null && media.playbackState === MediaPlayer.PlayingState
    readonly property bool failed: media !== null && media.error !== MediaPlayer.NoError
    readonly property real ratio: pictured && screen.sourceRect.width > 0 ? screen.sourceRect.height / screen.sourceRect.width : 9 / 16

    function toggle() {
      if (!loader.active) loader.active = true
      else if (playing) media.pause()
      else media.play()
    }

    width: parent ? parent.width : 0
    height: pictured ? Math.round(Math.min(width * ratio, root.maxHeight)) : bar.implicitHeight + Style.spacing.sm * 2

    Rectangle {
      anchors.fill: parent
      radius: Math.min(4, Style.cornerRadius)
      color: player.pictured ? "black" : Qt.alpha(Color.accent, 0.12)
    }

    VideoOutput {
      id: screen
      anchors.fill: parent
      visible: player.pictured
      fillMode: VideoOutput.PreserveAspectFit
    }

    Loader {
      id: loader
      active: false
      sourceComponent: MediaPlayer {
        source: player.address
        videoOutput: screen
        audioOutput: AudioOutput {}
        Component.onCompleted: play()
      }
    }

    Row {
      id: bar
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.sm
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.sm
      anchors.verticalCenter: player.pictured ? undefined : parent.verticalCenter
      anchors.bottom: player.pictured ? parent.bottom : undefined
      anchors.bottomMargin: Style.spacing.sm
      visible: !player.pictured || !player.playing
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: player.playing ? "󰏤" : "󰐊"
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      Text {
        textFormat: Text.PlainText
        width: parent.width - Style.space(40)
        elide: Text.ElideMiddle
        text: player.failed ? "cannot be played: " + player.address
          : (player.pictured ? "video" : "󰝚 sound") + " · " + player.address.replace(/^https?:\/\//, "")
        color: player.pictured ? "white" : root.dim
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) root.picked(player.address)
        else player.toggle()
      }
    }
  }

  Component { id: picture; Picture { address: parent.address; inline: parent.inline; moving: parent.modelData.moving === true } }
  Component { id: video; Player { address: parent.address; pictured: true } }
  Component { id: audio; Player { address: parent.address } }
}
