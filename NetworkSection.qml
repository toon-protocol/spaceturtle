import QtQuick
import qs.Commons
import qs.Ui

// The Network section: the relay's feed, and a page for each author. One
// cursor runs down the page; on an author page it passes the copyable details
// before the events. Where it is lives on the service, so it survives the panel
// closing.
Item {
  id: root

  required property var service

  readonly property color dim: Qt.darker(Color.foreground, 1.5)

  readonly property string profilePubkey: service.profilePubkey
  readonly property bool authorPage: profilePubkey !== ""
  readonly property var profile: service.profiles[profilePubkey] || ({})
  readonly property var shownEvents: authorPage ? service.eventsBy(profilePubkey) : service.events
  readonly property bool viewingSelf: authorPage && profilePubkey === service.selfPubkey

  // The "LABEL value" lines of an author page that have a value.
  readonly property var details: {
    if (!authorPage) return []
    var web = service.field(profilePubkey, "website")
    // Only the agent's own page: the relay's NIP-11 document says where this node is paid.
    var ilp = viewingSelf ? service.nodeIlp : ""
    var connector = viewingSelf ? service.nodeConnector : ""
    return [
      { label: "Web", value: web, openable: /^https?:\/\//.test(web) },
      { label: "Zap", value: service.field(profilePubkey, "lud16"), openable: false },
      { label: "ILP", value: ilp, openable: false },
      { label: "Node", value: connector, openable: false },
      { label: "Key", value: npub(profilePubkey), openable: false }
    ].filter(function(row) { return row.value !== "" })
  }

  // The cursor's targets, in order: details, events.
  readonly property int firstEvent: details.length
  readonly property int targetCount: firstEvent + shownEvents.length
  readonly property int cursor: Math.max(0, Math.min(service.cursor, targetCount - 1))
  // False while the pointer moves the cursor, so hovering never scrolls the page.
  property bool scrollOnCursor: true
  // True until the cursor's row has been scrolled to, after the panel opens or
  // an author page closes. Rows are rebuilt on every refresh, and must not
  // pull the page back each time.
  property bool cursorToRestore: true

  // The label of the detail row whose value was just copied, for its "copied" flash.
  property string copiedLabel: ""

  readonly property string statusText: {
    if (!service.loaded) return "Loading…"
    if (!service.online) return "Offline"
    return service.events.length === 1 ? "1 event" : service.events.length + " events"
  }

  function move(dy) {
    pointerGate.reset()
    root.scrollOnCursor = true
    service.cursor = Math.max(0, Math.min(root.cursor + dy, root.targetCount - 1))
    // The first target is not the top of the page: show what is above it too.
    if (service.cursor === 0) scroll.contentY = 0
  }

  function hover(index) {
    root.scrollOnCursor = false
    service.cursor = index
  }

  // Enter: an event opens its author's page, a detail is copied, the button is pressed.
  function activate() {
    if (root.targetCount === 0) return
    if (root.cursor >= root.firstEvent) {
      if (!root.authorPage) root.openProfile(root.shownEvents[root.cursor - root.firstEvent].pubkey)
    } else {
      root.copy(root.details[root.cursor])
    }
  }

  // Esc: from an author page to the feed. False when already on the feed.
  function back() {
    if (!root.authorPage) return false
    pointerGate.reset()
    root.scrollOnCursor = true
    root.copiedLabel = ""
    root.cursorToRestore = true
    service.profilePubkey = ""
    service.cursor = service.feedCursor
    return true
  }

  function key(text) {
    var detail = root.cursor < root.details.length ? root.details[root.cursor] : null
    if (text === "o" && detail && detail.openable) service.openUrl(detail.value)
  }

  function openProfile(pubkey) {
    pointerGate.reset()
    root.scrollOnCursor = true
    root.copiedLabel = ""
    service.feedCursor = root.cursor
    service.profilePubkey = pubkey
    service.cursor = 0
    scroll.contentY = 0
  }

  function copy(detail) {
    service.copy(detail.value)
    root.copiedLabel = detail.label
    copiedTimer.restart()
  }

  function restoreCursor(item) {
    root.cursorToRestore = false
    root.ensureVisible(item)
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

  // NIP-19: a public key as `npub1…`, the form other clients take.
  function npub(hex) {
    if (!/^[0-9a-f]{64}$/.test(hex)) return hex
    var charset = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
    var gen = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
    function polymod(values) {
      var chk = 1
      for (var i = 0; i < values.length; i++) {
        var top = chk >>> 25
        chk = ((chk & 0x1ffffff) << 5) ^ values[i]
        for (var j = 0; j < 5; j++) if ((top >>> j) & 1) chk ^= gen[j]
      }
      return chk >>> 0
    }
    var data = [], acc = 0, bits = 0
    for (var b = 0; b < 64; b += 2) {
      acc = (acc << 8) | parseInt(hex.substr(b, 2), 16)
      bits += 8
      while (bits >= 5) { bits -= 5; data.push((acc >>> bits) & 31) }
    }
    if (bits > 0) data.push((acc << (5 - bits)) & 31)
    var hrp = [3, 3, 3, 3, 0, 14, 16, 21, 2]  // "npub", expanded
    var mod = polymod(hrp.concat(data, [0, 0, 0, 0, 0, 0])) ^ 1
    for (var c = 0; c < 6; c++) data.push((mod >>> (5 * (5 - c))) & 31)
    return "npub1" + data.map(function(d) { return charset[d] }).join("")
  }

  function tagValue(event, name) {
    var tags = event.tags || []
    for (var i = 0; i < tags.length; i++)
      if (tags[i][0] === name && tags[i].length > 1) return String(tags[i][1])
    return ""
  }

  // What the event did, shown next to the author.
  function verbOf(event) {
    switch (event.kind) {
    case 6:
    case 16: return "reposted"
    case 7: return "reacted"
    case 1111: return "commented"
    case 30023: return "published"
    default: return tagValue(event, "e") !== "" ? "replied" : ""
    }
  }

  function bodyOf(event) {
    switch (event.kind) {
    case 6:
    case 16: return tagValue(event, "e").slice(0, 8)
    case 7: return event.content === "+" || event.content === "" ? "󰋑" : (event.content === "-" ? "󰋕" : event.content)
    case 30023: return tagValue(event, "title") || tagValue(event, "summary") || String(event.content || "")
    default: return String(event.content || "").trim()
    }
  }

  function ago(seconds) {
    var delta = Math.max(0, Math.floor(clock.now / 1000) - seconds)
    if (delta < 60) return "now"
    if (delta < 3600) return Math.floor(delta / 60) + "m"
    if (delta < 86400) return Math.floor(delta / 3600) + "h"
    return Math.floor(delta / 86400) + "d"
  }

  // Keeps a row that slides under a still pointer from taking the cursor.
  PointerMoveGate {
    id: pointerGate
    referenceItem: root
  }

  Timer {
    id: copiedTimer
    interval: 1500
    onTriggered: root.copiedLabel = ""
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
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    Column {
      id: column
      width: scroll.width
      spacing: Style.space(12)

      // =================== Feed ===================

      // ---------- Hero: icon · relay name · status ----------
      PanelHero {
        visible: !root.authorPage
        title: root.service.relayName || "Relay"
        meta: root.statusText
        iconComponent: Component {
          TurtleIcon {
            iconSize: Style.font.display
            variant: root.service.iconVariant
            color: Color.foreground
          }
        }
      }

      // ---------- Icon chooser, shown while "iconPreview" is set ----------
      Row {
        visible: root.service.iconPreview && !root.authorPage
        spacing: Style.space(22)

        Repeater {
          model: 5

          Column {
            id: choice
            required property int index
            spacing: Style.space(6)

            TurtleIcon {
              anchors.horizontalCenter: parent.horizontalCenter
              iconSize: Style.font.display
              variant: choice.index + 1
              color: Color.foreground
            }

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: String(choice.index + 1)
                color: choice.index + 1 === root.service.iconVariant ? Color.accent : root.dim
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              TurtleIcon {
                anchors.verticalCenter: parent.verticalCenter
                iconSize: Style.space(15)
                variant: choice.index + 1
                color: Color.foreground
              }
            }
          }
        }
      }

      // =================== Author page ===================

      // ---------- Back ----------
      Button {
        visible: root.authorPage
        text: "󰅁  " + (root.service.relayName || "Relay")
        foreground: root.dim
        fontSize: Style.font.bodySmall
        onClicked: root.back()
      }

      // ---------- Profile hero: picture · name · handle ----------
      Item {
        visible: root.authorPage
        width: parent.width
        implicitHeight: Math.max(profilePicture.height, profileLabels.implicitHeight)

        Avatar {
          id: profilePicture
          size: Style.space(64)
          source: root.service.field(root.profilePubkey, "picture")
          label: root.service.nameOf(root.profilePubkey)
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          id: profileLabels
          anchors.left: profilePicture.right
          anchors.leftMargin: Style.space(14)
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(3)

          Row {
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText
              text: root.service.nameOf(root.profilePubkey)
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
            }

            // NIP-24 `bot`: the profile says it is automated.
            Rectangle {
              visible: root.profile.bot === true
              anchors.verticalCenter: parent.verticalCenter
              width: botLabel.implicitWidth + Style.space(8)
              height: botLabel.implicitHeight + Style.space(2)
              radius: Math.min(4, Style.cornerRadius)
              color: Qt.alpha(Color.accent, 0.22)

              Text {
                id: botLabel
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "AGENT"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            visible: text !== ""
            text: root.service.field(root.profilePubkey, "nip05")
              || (root.service.field(root.profilePubkey, "display_name") !== ""
                  && root.service.field(root.profilePubkey, "name") !== root.service.field(root.profilePubkey, "display_name")
                ? "@" + root.service.field(root.profilePubkey, "name") : "")
            color: root.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            textFormat: Text.PlainText
            text: (root.shownEvents.length === 1 ? "1 event" : root.shownEvents.length + " events").toUpperCase()
            color: root.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
          }
        }
      }

      // ---------- About ----------
      Text {
        visible: root.authorPage && text !== ""
        textFormat: Text.PlainText
        width: parent.width
        text: root.service.field(root.profilePubkey, "about")
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        wrapMode: Text.Wrap
      }

      // ---------- Details: Enter or a click copies the value ----------
      Column {
        visible: root.details.length > 0
        width: parent.width

        Repeater {
          model: root.details

          DetailRow {}
        }
      }

      // ---------- Counters ----------
      Item {
        visible: root.authorPage
        width: parent.width
        implicitHeight: counters.implicitHeight

        Row {
          id: counters
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(18)

          Counter {
            count: String(root.service.followerCount(root.profilePubkey))
            label: root.service.followerCount(root.profilePubkey) === 1 ? "Follower" : "Followers"
          }

          Counter {
            count: String(root.service.followingCount(root.profilePubkey))
            label: "Following"
          }

          // Only this agent node knows who subscribed to its own relay's feed.
          Counter {
            visible: root.viewingSelf
            count: root.service.subscribers < 0 ? "–" : String(root.service.subscribers)
            label: root.service.subscribers === 1 ? "Subscriber" : "Subscribers"
          }
        }
      }

      // =================== Shared: separator, empty state, events ===================

      PanelSeparator {}

      Text {
        visible: !root.authorPage && root.service.events.length === 0
        textFormat: Text.PlainText
        text: !root.service.loaded ? "Fetching events…" : (root.service.online ? "No events yet." : "The relay is not running.")
        color: root.dim
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.italic: true
      }

      Text {
        visible: root.authorPage && root.shownEvents.length === 0
        textFormat: Text.PlainText
        text: "Nothing posted here yet."
        color: root.dim
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.italic: true
      }

      // ---------- Events, newest first ----------
      Column {
        width: parent.width

        Repeater {
          model: root.shownEvents

          EventRow {}
        }
      }
    }
  }

  // One event of the list: picture, author, what it did, when, and its text.
  // On the feed, Enter or a click opens the author's page.
  component EventRow: CursorSurface {
    id: row
    required property var modelData
    required property int index
    readonly property int target: root.firstEvent + index

    hasCursor: root.cursor === target
    width: parent ? parent.width : 0
    height: Math.max(avatar.height, rowText.implicitHeight) + Style.spacing.lg * 2

    onHasCursorChanged: if (hasCursor && root.scrollOnCursor) root.ensureVisible(row)
    // The cursor the panel was closed on: bring it back into view.
    Component.onCompleted: if (hasCursor && root.cursorToRestore) Qt.callLater(root.restoreCursor, row)

    Avatar {
      id: avatar
      size: Style.space(28)
      source: root.service.field(row.modelData.pubkey, "picture")
      label: root.service.nameOf(row.modelData.pubkey)
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.lg
      anchors.top: parent.top
      anchors.topMargin: Style.spacing.lg
    }

    Column {
      id: rowText
      anchors.left: avatar.right
      anchors.leftMargin: Style.space(10)
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.lg
      anchors.top: avatar.top
      spacing: Style.space(3)

      Item {
        width: parent.width
        implicitHeight: author.implicitHeight

        Text {
          id: author
          textFormat: Text.PlainText
          anchors.left: parent.left
          width: Math.min(implicitWidth, parent.width - verb.implicitWidth - time.implicitWidth - Style.space(16))
          elide: Text.ElideRight
          text: root.service.nameOf(row.modelData.pubkey)
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }

        Text {
          id: verb
          textFormat: Text.PlainText
          anchors.left: author.right
          anchors.leftMargin: Style.space(6)
          anchors.baseline: author.baseline
          text: root.verbOf(row.modelData)
          color: root.dim
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }

        Text {
          id: time
          textFormat: Text.PlainText
          anchors.right: parent.right
          anchors.baseline: author.baseline
          text: root.ago(row.modelData.created_at)
          color: root.dim
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        visible: text !== ""
        text: root.bodyOf(row.modelData)
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        wrapMode: Text.Wrap
        maximumLineCount: root.authorPage ? 12 : 4
        elide: Text.ElideRight
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: root.authorPage ? Qt.ArrowCursor : Qt.PointingHandCursor
      onPositionChanged: function(mouse) { if (pointerGate.moved(row, mouse)) root.hover(row.target) }
      onClicked: {
        root.hover(row.target)
        root.activate()
      }
    }
  }

  // One "LABEL value" line of an author page. A long value is cut in the
  // middle; Enter or a click copies the whole of it.
  component DetailRow: CursorSurface {
    id: detail
    required property var modelData
    required property int index
    readonly property bool justCopied: root.copiedLabel === modelData.label

    hasCursor: root.cursor === index
    width: parent ? parent.width : 0
    height: detailValue.implicitHeight + Style.spacing.sm * 2

    onHasCursorChanged: if (hasCursor && root.scrollOnCursor) root.ensureVisible(detail)

    Text {
      id: detailLabel
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.lg
      anchors.baseline: detailValue.baseline
      width: Style.space(44)
      text: detail.modelData.label.toUpperCase()
      color: root.dim
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
    }

    Text {
      id: detailValue
      textFormat: Text.PlainText
      anchors.left: detailLabel.right
      anchors.right: openGlyph.visible ? openGlyph.left : parent.right
      anchors.rightMargin: Style.spacing.lg
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideMiddle
      text: detail.justCopied ? "copied" : detail.modelData.value
      color: detail.justCopied ? Color.accent : Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onPositionChanged: function(mouse) { if (pointerGate.moved(detail, mouse)) root.hover(detail.index) }
      onClicked: {
        root.hover(detail.index)
        root.activate()
      }
    }

    // Opens a web address in the browser; `o` does the same from the keyboard.
    Text {
      id: openGlyph
      visible: detail.modelData.openable
      textFormat: Text.PlainText
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.lg
      anchors.baseline: detailValue.baseline
      text: "󰏌"
      color: detail.hasCursor ? Color.foreground : root.dim
      font.family: Style.font.family
      font.pixelSize: Style.font.body

      MouseArea {
        anchors.fill: parent
        anchors.margins: -Style.space(4)
        cursorShape: Qt.PointingHandCursor
        onClicked: root.service.openUrl(detail.modelData.value)
      }
    }
  }

  // "12 FOLLOWERS": a number with its small-caps label.
  component Counter: Row {
    property string count: ""
    property string label: ""
    spacing: Style.space(5)

    Text {
      id: counterValue
      textFormat: Text.PlainText
      text: parent.count
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Text {
      textFormat: Text.PlainText
      anchors.baseline: counterValue.baseline
      text: parent.label.toUpperCase()
      color: root.dim
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
    }
  }
}
