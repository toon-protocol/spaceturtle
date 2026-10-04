import QtQuick
import qs.Commons
import qs.Ui

// The Network section: the relay's feed, a thread for each event and a page for
// each author. One cursor runs down the page; on an author page it passes the
// copyable details before the events. Where it is lives on the service, so it survives the panel
// closing.
Item {
  id: root

  required property var service

  readonly property color dim: Qt.darker(Color.foreground, 1.5)

  readonly property string profilePubkey: service.profilePubkey
  readonly property string threadId: service.threadId
  readonly property bool threadView: threadId !== ""
  readonly property bool authorPage: !threadView && profilePubkey !== ""
  readonly property var profile: service.profiles[profilePubkey] || ({})
  readonly property var shownEvents: threadView ? service.threadRows(threadId)
    : (authorPage ? service.eventsBy(profilePubkey) : service.events)
  // The event the cursor is on, or null (also on a missing event's row).
  readonly property var cursorEvent: {
    var event = cursor >= firstEvent ? shownEvents[cursor - firstEvent] : null
    return event && event.missing !== true ? event : null
  }
  // Notes, comments and long-form posts: what can be replied to, reacted to or reposted.
  function isNote(event) { return !!event && [1, 1111, 30023].indexOf(event.kind) !== -1 }
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

  // A Request being written about the thing under the cursor: its kind, and
  // the author or note it names. Empty while none is.
  property string composeKind: ""
  property string composePubkey: ""
  property string composeEvent: ""
  // Why a Request was not started, shown briefly.
  property string notice: ""

  // The text box has the keys while it has focus; the panel is asked to take them back.
  readonly property bool typing: composeInput.activeFocus
  signal leaveInput()

  readonly property string composeText: composeKind === "" ? "" : (service.requestVerbs[composeKind] + " "
    + (composeEvent !== "" ? "this note" : service.nameOf(composePubkey)) + " — add a line of your own, or none")

  // Starts a Request, unless the same kind is already waiting on the same subject.
  function compose(kind, pubkey, event) {
    root.notice = ""
    if (service.waitingAbout(kind, pubkey, event).length > 0) {
      root.notice = "A " + kind + " Request for this is already waiting."
      noticeTimer.restart()
      return
    }
    root.composeKind = kind
    root.composePubkey = pubkey
    root.composeEvent = event
    composeInput.text = ""
    composeInput.forceActiveFocus()
  }

  function sendCompose() {
    service.submitAbout(root.composeKind, root.composePubkey, root.composeEvent, composeInput.text)
    cancelCompose()
  }

  function cancelCompose() {
    if (root.composeKind === "") return
    root.composeKind = ""
    root.leaveInput()
  }
  // Leaving the view or the section leaves the Request unwritten.
  onVisibleChanged: if (!visible) cancelCompose()

  // The label of the detail row whose value was just copied, or "event:" and the
  // id of the event whose text was, for its "copied" flash.
  property string copiedLabel: ""

  readonly property string statusText: {
    if (!service.loaded) return "Loading…"
    if (!service.online) return "Offline"
    return service.events.length === 1 ? "1 event" : service.events.length + " events"
  }

  // The row under the cursor, so that a row taller than the page can be read.
  property Item cursorItem: null

  // Scrolls within a row too tall to show at once, before the cursor leaves it.
  // True when it did.
  function scrollWithin(dy) {
    var item = root.cursorItem
    if (!item || item.height <= scroll.height) return false
    var top = item.mapToItem(column, 0, 0).y
    var bottom = top + item.height
    var step = Math.max(Style.space(24), scroll.height / 2)
    var maxY = Math.max(0, scroll.contentHeight - scroll.height)
    if (dy > 0 && bottom > scroll.contentY + scroll.height + 1) {
      scroll.contentY = Math.min(maxY, scroll.contentY + step, bottom - scroll.height)
      return true
    }
    if (dy < 0 && top < scroll.contentY - 1) {
      scroll.contentY = Math.max(0, scroll.contentY - step, top)
      return true
    }
    return false
  }

  function move(dy) {
    pointerGate.reset()
    root.scrollOnCursor = true
    if (root.threadView && root.scrollWithin(dy)) return
    service.cursor = Math.max(0, Math.min(root.cursor + dy, root.targetCount - 1))
    // The first target is not the top of the page: show what is above it too.
    if (service.cursor === 0) scroll.contentY = 0
  }

  function hover(index) {
    root.scrollOnCursor = false
    service.cursor = index
  }

  // Enter: an event opens its thread (in a thread, its author's page), a detail is copied.
  function activate() {
    if (root.targetCount === 0) return
    if (root.cursor >= root.firstEvent) {
      var event = root.cursorEvent
      if (!event) return
      if (root.threadView) service.openAuthor(event.pubkey)
      else service.openThread(event.id)
    } else {
      root.copy(root.details[root.cursor])
    }
  }

  // Esc: back to the view before (the feed, an author page or a thread). False
  // when already on the feed.
  function back() {
    if (!service.goBack()) return false
    pointerGate.reset()
    root.scrollOnCursor = true
    root.copiedLabel = ""
    root.cursorToRestore = true
    return true
  }

  // `y` or `c` copies the detail or the event's text under the cursor, `u` the
  // address of its first picture, `o` opens a web address,
  // `a` opens the author of the event under the cursor. `f` asks the agent to
  // follow or unfollow the author of the page; `w`, `e` and `b` to reply to,
  // react to or repost the note under the cursor.
  function key(text) {
    var detail = root.cursor < root.details.length ? root.details[root.cursor] : null
    if (text === "o" && detail && detail.openable) service.openUrl(detail.value)
    else if ((text === "y" || text === "c") && detail) root.copy(detail)
    else if ((text === "y" || text === "c") && root.cursorEvent) root.copyEvent(root.cursorEvent)
    else if (text === "u" && root.cursorEvent) root.copyFromEvent(root.cursorEvent, service.firstPicture(root.cursorEvent))
    else if (text === "a" && root.cursorEvent && !root.authorPage) service.openAuthor(root.cursorEvent.pubkey)
    else if (text === "f" && root.authorPage && !root.viewingSelf)
      root.compose(service.followsAuthor(root.profilePubkey) ? "unfollow" : "follow", root.profilePubkey, "")
    else if (root.isNote(root.cursorEvent)) {
      var kind = ({ w: "reply", e: "react", b: "repost" })[text]
      if (kind) root.compose(kind, root.cursorEvent.pubkey, root.cursorEvent.id)
    }
  }

  // A thread or an author page was opened, here or from Activity.
  Connections {
    target: root.service
    function onViewOpened() {
      root.cancelCompose()
      pointerGate.reset()
      root.scrollOnCursor = true
      root.copiedLabel = ""
      root.cursorToRestore = true
      scroll.contentY = 0
    }
  }

  function copy(detail) {
    service.copy(detail.value)
    root.copiedLabel = detail.label
    copiedTimer.restart()
  }

  // The whole of an event's text, not cut to the lines its row shows.
  function copyEvent(event) { root.copyFromEvent(event, root.textOf(event)) }

  // `u` or a click on a picture copies its address.
  function copyFromEvent(event, value) {
    if (event.missing === true || value === "") return
    service.copy(value)
    root.copiedLabel = "event:" + event.id
    copiedTimer.restart()
  }

  // A row taller than the page, a long-form post, is shown from its start.
  function restoreCursor(item) {
    root.cursorToRestore = false
    if (item && item.height > scroll.height) scroll.contentY = Math.max(0, item.mapToItem(column, 0, 0).y)
    else root.ensureVisible(item)
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

  // An event's parts are resolved by relay-events; nothing here looks at a kind.
  function partsOf(event) { return event.parts || ({}) }

  // What the event did, shown next to the author.
  function verbOf(event) { return String(partsOf(event).label || "") }

  function textOf(event) {
    var parts = partsOf(event)
    var lines = [parts.title, parts.summary, parts.body].filter(function(line) { return line })
    if (lines.length === 0 && parts.ref) lines.push(String(parts.ref).slice(0, 8))
    return lines.join("\n")
  }

  // What a row shows: a picture shown under the text is not also named in it.
  function bodyOf(event) { return service.withoutMedia(textOf(event), partsOf(event).media) }

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
    id: noticeTimer
    interval: 3000
    onTriggered: root.notice = ""
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

  // ---------- A Request about the author or note under the cursor ----------
  Column {
    id: composeBar
    visible: root.composeKind !== "" || root.notice !== ""
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    spacing: Style.spacing.sm

    Text {
      width: parent.width
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      text: root.composeKind !== "" ? root.composeText : root.notice
      color: root.dim
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.italic: true
    }

    Rectangle {
      visible: root.composeKind !== ""
      width: parent.width
      height: composeInput.implicitHeight + Style.spacing.lg * 2
      color: "transparent"
      radius: Math.min(4, Style.cornerRadius)
      border.width: 1
      border.color: composeInput.activeFocus ? Color.accent : root.dim
      // Whatever the text box does not use stops here, so the panel never sees it.
      Keys.onPressed: function(event) { event.accepted = true }

      TextInput {
        id: composeInput
        anchors.fill: parent
        anchors.margins: Style.spacing.lg
        color: Color.foreground
        selectionColor: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        clip: true
        // Enter sends; Esc cancels. Every other key is typed.
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.sendCompose()
            event.accepted = true
          } else if (event.key === Qt.Key_Escape) {
            root.cancelCompose()
            event.accepted = true
          }
        }

        Text {
          visible: composeInput.text === ""
          text: "Enter sends, Esc cancels"
          color: root.dim
          font: composeInput.font
        }
      }
    }
  }

  Flickable {
    id: scroll
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: composeBar.visible ? composeBar.top : parent.bottom
    anchors.bottomMargin: composeBar.visible ? Style.spacing.sm : 0
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
        visible: !root.authorPage && !root.threadView
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
        visible: root.service.iconPreview && !root.authorPage && !root.threadView
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

      // =================== Thread and author page ===================

      // ---------- Back ----------
      Button {
        visible: root.authorPage || root.threadView
        text: "󰅁  " + (root.service.trail.length > 1 ? "Back" : (root.service.relayName || "Relay"))
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

      // ---------- Follow or unfollow, by the agent's follow list ----------
      Text {
        visible: root.authorPage && !root.viewingSelf
        width: parent.width
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: {
          var waiting = root.service.waitingKinds(root.profilePubkey, "")
          var verb = root.service.followsAuthor(root.profilePubkey) ? "unfollow" : "follow"
          if (waiting.length > 0) return "A " + waiting.join(" and an ") + " Request is waiting."
          return "Your agent " + (verb === "unfollow" ? "follows" : "does not follow") + " this author. f asks it to " + verb + "."
        }
        color: root.dim
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      // =================== Shared: separator, empty state, events ===================

      PanelSeparator {}

      Text {
        visible: !root.authorPage && !root.threadView && root.service.events.length === 0
        textFormat: Text.PlainText
        text: !root.service.loaded ? "Fetching events…" : (root.service.online ? "No events yet." : "The relay is not running.")
        color: root.dim
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.italic: true
      }

      Text {
        visible: (root.authorPage || root.threadView) && root.shownEvents.length === 0
        textFormat: Text.PlainText
        text: root.threadView ? "This event is no longer on the relay." : "Nothing posted here yet."
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
    // A thread indents a reply under what it replies to.
    readonly property int depth: Math.min(modelData.depth || 0, 6)
    readonly property bool missing: modelData.missing === true
    readonly property real indent: depth * Style.space(14)
    readonly property bool justCopied: !missing && root.copiedLabel === "event:" + modelData.id
    // Requests already waiting on this note, so it is not asked twice.
    readonly property string waitingText: missing ? "" : root.service.waitingKinds("", modelData.id)
      .map(function(k) { return k + " waiting" }).join(" · ")

    hasCursor: root.cursor === target
    width: parent ? parent.width : 0
    height: (missing ? gone.implicitHeight : Math.max(avatar.height, rowText.implicitHeight)) + Style.spacing.lg * 2

    onHasCursorChanged: {
      if (!hasCursor) { if (root.cursorItem === row) root.cursorItem = null; return }
      root.cursorItem = row
      if (root.scrollOnCursor) root.ensureVisible(row)
    }
    // The cursor the panel was closed on: bring it back into view.
    Component.onCompleted: {
      if (hasCursor) root.cursorItem = row
      if (hasCursor && root.cursorToRestore) Qt.callLater(root.restoreCursor, row)
    }
    Component.onDestruction: if (root.cursorItem === row) root.cursorItem = null

    // First, so that the picture and the name sit above it.
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onPositionChanged: function(mouse) { if (pointerGate.moved(row, mouse)) root.hover(row.target) }
      onClicked: function(mouse) {
        root.hover(row.target)
        if (mouse.button === Qt.RightButton) root.copyEvent(row.modelData)
        else root.activate()
      }
    }

    // An event the thread refers to and the relay does not hold: shown, not skipped.
    Text {
      id: gone
      visible: row.missing
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.lg + row.indent
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.lg
      anchors.top: parent.top
      anchors.topMargin: Style.spacing.lg
      wrapMode: Text.Wrap
      text: "󰇘  Event " + String(row.modelData.id).slice(0, 8) + " is not on this relay"
      color: root.dim
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.italic: true
    }

    Avatar {
      id: avatar
      visible: !row.missing
      size: Style.space(28)
      source: root.service.field(row.modelData.pubkey, "picture")
      label: root.service.nameOf(row.modelData.pubkey)
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.lg + row.indent
      anchors.top: parent.top
      anchors.topMargin: Style.spacing.lg

      // A picture opens its author's page.
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.hover(row.target)
          root.service.openAuthor(row.modelData.pubkey)
        }
      }
    }

    Column {
      id: rowText
      visible: !row.missing
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

          // A name opens its author's page.
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.hover(row.target)
              root.service.openAuthor(row.modelData.pubkey)
            }
          }
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
          text: row.justCopied ? "copied" : root.ago(row.modelData.created_at)
          color: row.justCopied ? Color.accent : root.dim
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
        // In a thread the event under the cursor is read in full; the page scrolls within it.
        maximumLineCount: root.threadView && row.hasCursor ? 100000 : (root.authorPage ? 12 : 4)
        elide: Text.ElideRight
      }

      MediaStrip {
        width: parent.width
        sources: root.partsOf(row.modelData).media || []
        dim: root.dim
        onPicked: function(address) {
          root.hover(row.target)
          root.copyFromEvent(row.modelData, address)
        }
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        visible: text !== ""
        text: row.waitingText
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        visible: row.hasCursor && root.isNote(row.modelData)
        text: "w replies · e reacts · b reposts"
        color: root.dim
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
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
