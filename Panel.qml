import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar pill + popup listing the social events stored on the agent node's relay.
// The data comes from the `relay-events` script next to this file, which asks
// `toon` for the relay's read address and queries it.
Panel {
  id: root
  moduleName: "toon.relay-feed"
  ipcTarget: "toon.relay-feed"

  // Inline shell.json settings: { "id": "toon.relay-feed", "interval": 30, "limit": 40 }
  readonly property int refreshSeconds: Math.max(5, Number(setting("interval", 30)) || 30)
  readonly property int eventLimit: Math.max(1, Number(setting("limit", 40)) || 40)
  // Which TurtleIcon drawing to use, and whether the popup lists them all to choose from.
  readonly property int iconVariant: Number(setting("icon", 1)) || 1
  readonly property bool iconPreview: setting("iconPreview", false) === true

  readonly property string script: Qt.resolvedUrl("relay-events").toString().replace(/^file:\/\//, "")
  readonly property string followScript: Qt.resolvedUrl("relay-follow").toString().replace(/^file:\/\//, "")

  property bool loaded: false
  property bool online: false
  property string relayName: ""
  // pubkey -> the parsed kind 0 metadata of its newest profile event.
  property var profiles: ({})
  // The profile page being shown; empty while the feed is.
  property string profilePubkey: ""
  readonly property var profile: profiles[profilePubkey] || ({})
  readonly property var profileEvents: events.filter(function(e) { return e.pubkey === profilePubkey })
  // The agent identity's own key, and pubkey -> the keys its newest follow list names.
  property string selfPubkey: ""
  property var followMap: ({})
  // How many hold a subscription to this relay's live feed; -1 while it is not sold.
  property int subscribers: -1
  readonly property bool viewingSelf: profilePubkey !== "" && profilePubkey === selfPubkey
  readonly property bool following: (followMap[selfPubkey] || []).indexOf(profilePubkey) !== -1
  // What the follow button was last asked to do, shown until the relay confirms it.
  property string followPending: ""

  // The label of the detail row whose value was just copied, for its "copied" flash.
  property string copiedLabel: ""
  property var events: []
  // Newest created_at the user has seen in the popup; anything newer tints the pill.
  property real seenAt: 0
  readonly property real newestAt: events.length > 0 ? events[0].created_at : 0
  readonly property bool hasUnseen: loaded && newestAt > seenAt

  readonly property color dim: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.5)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function open() {
    root.controller.show()
    root.refresh()
    root.seenAt = root.newestAt
  }

  function refresh() {
    if (!fetchProc.running) fetchProc.running = true
  }

  function applyReport(report) {
    var map = {}
    var profiles = report.profiles || []
    // Oldest first so a newer profile event overwrites an older one.
    profiles.sort(function(a, b) { return a.created_at - b.created_at })
    for (var i = 0; i < profiles.length; i++) {
      try {
        var meta = JSON.parse(profiles[i].content)
        if (meta !== null && typeof meta === "object") map[profiles[i].pubkey] = meta
      } catch (e) {}
    }
    // pubkey -> followed keys, from each author's newest kind 3.
    var follows = report.follows || []
    follows.sort(function(a, b) { return a.created_at - b.created_at })
    var followed = {}
    for (var f = 0; f < follows.length; f++) {
      var keys = []
      var tags = follows[f].tags || []
      for (var t = 0; t < tags.length; t++)
        if (tags[t][0] === "p" && tags[t].length > 1) keys.push(String(tags[t][1]))
      followed[follows[f].pubkey] = keys
    }

    var list = report.events || []
    list.sort(function(a, b) { return b.created_at - a.created_at })

    var first = !root.loaded
    root.profiles = map
    root.followMap = followed
    root.selfPubkey = report.self || ""
    root.subscribers = typeof report.subscribers === "number" ? report.subscribers : -1
    root.events = list
    root.online = report.online === true
    root.relayName = report.name || ""
    root.loaded = true
    // Nothing is "new" on the first load, nor while the popup is showing it.
    if (first || root.opened) root.seenAt = root.newestAt
  }

  function field(pubkey, name) {
    var meta = profiles[pubkey]
    var value = meta ? meta[name] : undefined
    return typeof value === "string" ? value.trim() : ""
  }

  function nameOf(pubkey) {
    return field(pubkey, "display_name") || field(pubkey, "name") || String(pubkey || "").slice(0, 8)
  }

  function authorOf(event) {
    return nameOf(event.pubkey)
  }

  function openProfile(pubkey) {
    root.copiedLabel = ""
    root.profilePubkey = pubkey
    scroll.contentY = 0
  }

  function closeProfile() {
    root.profilePubkey = ""
    scroll.contentY = 0
  }

  function close() {
    root.controller.hide()
    root.profilePubkey = ""
  }

  function copy(label, value) {
    if (value === "") return
    // Passed as an argument, never through a shell: the value comes from a profile.
    Quickshell.execDetached(["wl-copy", "--", value])
    root.copiedLabel = label
    copiedTimer.restart()
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

  function followingCount(pubkey) {
    return (followMap[pubkey] || []).length
  }

  function followerCount(pubkey) {
    var count = 0
    for (var author in followMap)
      if (followMap[author].indexOf(pubkey) !== -1) count++
    return count
  }

  function toggleFollow() {
    if (followProc.running || profilePubkey === "" || viewingSelf) return
    root.followPending = root.following ? "unfollow" : "follow"
    followProc.command = [root.followScript, root.followPending, root.profilePubkey]
    followProc.running = true
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

  readonly property string statusText: {
    if (!loaded) return "Loading…"
    if (!online) return "Offline"
    return events.length === 1 ? "1 event" : events.length + " events"
  }

  Process {
    id: fetchProc
    command: [root.script, String(root.eventLimit)]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.applyReport(JSON.parse(String(text || "").trim()))
        } catch (e) {
          // Keep the last good feed visible.
          root.online = false
          root.loaded = true
        }
      }
    }
  }

  // Publishes the changed follow list, then re-reads the relay to show it.
  Process {
    id: followProc
    onExited: {
      root.followPending = ""
      root.refresh()
    }
  }

  Timer {
    interval: root.refreshSeconds * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: copiedTimer
    interval: 1500
    onTriggered: root.copiedLabel = ""
  }

  // Drives the relative timestamps while the popup is open.
  Timer {
    id: clock
    property real now: Date.now()
    interval: 30000
    running: root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: now = Date.now()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        TurtleIcon {
          anchors.centerIn: parent
          iconSize: Style.space(15)
          variant: root.iconVariant
          color: root.bar ? root.bar.foreground : Color.foreground
        }
      }
    }
    opacity: root.online ? 1.0 : 0.45
    tooltipText: ""
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }

    // Unseen-events dot, in the theme's accent.
    Rectangle {
      visible: root.hasUnseen
      width: Style.space(5)
      height: width
      radius: width / 2
      color: Color.accent
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.rightMargin: Style.space(3)
      anchors.topMargin: Style.space(5)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(Math.min(column.implicitHeight, Style.space(460)))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dx < 0 && root.profilePubkey !== "") { root.closeProfile(); return }
        scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height, scroll.contentY + dy * Style.space(48)))
      }
      onReturnRequested: root.refresh()
      onCloseRequested: root.profilePubkey !== "" ? root.closeProfile() : root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

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
          Item {
            visible: root.profilePubkey === ""
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

            TurtleIcon {
              id: heroIcon
              iconSize: Style.font.display
              variant: root.iconVariant
              color: root.bar.foreground
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(12)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                width: parent.width
                elide: Text.ElideRight
                text: root.relayName || "Relay"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                textFormat: Text.PlainText
                text: root.statusText.toUpperCase()
                color: root.dim
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
              }
            }
          }

          // ---------- Icon chooser, shown while "iconPreview" is set ----------
          Row {
            visible: root.iconPreview && root.profilePubkey === ""
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
                  color: root.bar.foreground
                }

                Row {
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: Style.space(6)

                  Text {
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(choice.index + 1)
                    color: choice.index + 1 === root.iconVariant ? Color.accent : root.dim
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  TurtleIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    iconSize: Style.space(15)
                    variant: choice.index + 1
                    color: root.bar.foreground
                  }
                }
              }
            }
          }

          // =================== Profile page ===================

          // ---------- Back ----------
          Item {
            visible: root.profilePubkey !== ""
            width: parent.width
            implicitHeight: backLabel.implicitHeight + Style.space(8)

            Rectangle {
              width: backLabel.implicitWidth + Style.space(16)
              height: parent.height
              radius: Style.cornerRadius
              color: backArea.containsMouse ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent"

              Text {
                id: backLabel
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "󰅁  " + (root.relayName || "Relay")
                color: backArea.containsMouse ? Style.hoverStateColor(root.bar.foreground, Color.accent) : root.dim
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                id: backArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeProfile()
              }
            }
          }

          // ---------- Profile hero: picture · name · handle ----------
          Item {
            visible: root.profilePubkey !== ""
            width: parent.width
            implicitHeight: Math.max(profilePicture.height, profileLabels.implicitHeight)

            Avatar {
              id: profilePicture
              size: Style.space(64)
              source: root.field(root.profilePubkey, "picture")
              label: root.nameOf(root.profilePubkey)
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
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
                  text: root.nameOf(root.profilePubkey)
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
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
                    font.family: root.bar.fontFamily
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
                text: root.field(root.profilePubkey, "nip05")
                  || (root.field(root.profilePubkey, "display_name") !== "" && root.field(root.profilePubkey, "name") !== root.field(root.profilePubkey, "display_name")
                    ? "@" + root.field(root.profilePubkey, "name") : "")
                color: root.dim
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Text {
                textFormat: Text.PlainText
                text: (root.profileEvents.length === 1 ? "1 event" : root.profileEvents.length + " events").toUpperCase()
                color: root.dim
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
              }
            }
          }

          // ---------- About ----------
          Text {
            visible: root.profilePubkey !== "" && text !== ""
            textFormat: Text.PlainText
            width: parent.width
            text: root.field(root.profilePubkey, "about")
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
          }

          // ---------- Details: click a value to copy it ----------
          Column {
            visible: root.profilePubkey !== ""
            width: parent.width
            spacing: Style.space(5)

            DetailRow {
              label: "Web"
              value: root.field(root.profilePubkey, "website")
              openable: /^https?:\/\//.test(value)
            }

            DetailRow {
              label: "Zap"
              value: root.field(root.profilePubkey, "lud16")
            }

            // Not in NIP-01: what a TOON agent node says about where to pay it.
            DetailRow {
              label: "ILP"
              value: root.field(root.profilePubkey, "ilp_address")
            }

            DetailRow {
              label: "Node"
              value: root.field(root.profilePubkey, "connector")
            }

            DetailRow {
              label: "Key"
              value: root.npub(root.profilePubkey)
            }
          }

          // ---------- Counters, and the follow button on someone else's profile ----------
          Item {
            visible: root.profilePubkey !== ""
            width: parent.width
            implicitHeight: Math.max(counters.implicitHeight, followChip.height)

            Row {
              id: counters
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(18)

              Counter {
                count: String(root.followerCount(root.profilePubkey))
                label: root.followerCount(root.profilePubkey) === 1 ? "Follower" : "Followers"
              }

              Counter {
                count: String(root.followingCount(root.profilePubkey))
                label: "Following"
              }

              // Only this agent node knows who subscribed to its own relay's feed.
              Counter {
                visible: root.viewingSelf
                count: root.subscribers < 0 ? "–" : String(root.subscribers)
                label: root.subscribers === 1 ? "Subscriber" : "Subscribers"
              }
            }

            ActionChip {
              id: followChip
              visible: !root.viewingSelf && root.selfPubkey !== ""
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              highlighted: !root.following
              label: root.followPending !== "" ? "…" : (root.following ? "Unfollow" : "Follow")
              onActivated: root.toggleFollow()
            }
          }

          // =================== Shared: separator, empty state, events ===================

          PanelSeparator {
            width: parent.width
            foreground: root.bar.foreground
          }

          Text {
            visible: root.profilePubkey === "" && root.events.length === 0
            textFormat: Text.PlainText
            text: !root.loaded ? "Fetching events…" : (root.online ? "No events yet." : "The relay is not running.")
            color: root.dim
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.italic: true
          }

          Text {
            visible: root.profilePubkey !== "" && root.profileEvents.length === 0
            textFormat: Text.PlainText
            text: "Nothing posted here yet."
            color: root.dim
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.italic: true
          }

          // ---------- Events, newest first ----------
          Repeater {
            model: root.profilePubkey === "" ? root.events : root.profileEvents

            Item {
              id: row
              required property var modelData
              width: column.width
              implicitHeight: Math.max(avatar.height, rowText.implicitHeight)

              Avatar {
                id: avatar
                size: Style.space(28)
                source: root.field(row.modelData.pubkey, "picture")
                label: root.authorOf(row.modelData)
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.top: parent.top
                opacity: authorArea.containsMouse ? 0.8 : 1.0
              }

              Column {
                id: rowText
                anchors.left: avatar.right
                anchors.leftMargin: Style.space(10)
                anchors.right: parent.right
                anchors.top: parent.top
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
                    text: root.authorOf(row.modelData)
                    color: Color.accent
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                    font.underline: authorArea.containsMouse
                  }

                  Text {
                    id: verb
                    textFormat: Text.PlainText
                    anchors.left: author.right
                    anchors.leftMargin: Style.space(6)
                    anchors.baseline: author.baseline
                    text: root.verbOf(row.modelData)
                    color: root.dim
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Text {
                    id: time
                    textFormat: Text.PlainText
                    anchors.right: parent.right
                    anchors.baseline: author.baseline
                    text: root.ago(row.modelData.created_at)
                    color: root.dim
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  visible: text !== ""
                  text: root.bodyOf(row.modelData)
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.body
                  wrapMode: Text.Wrap
                  maximumLineCount: root.profilePubkey === "" ? 4 : 12
                  elide: Text.ElideRight
                }
              }

              // The picture and the name open the author's profile page.
              MouseArea {
                id: authorArea
                x: 0
                y: 0
                width: avatar.width + Style.space(10) + author.width
                height: Math.max(avatar.height, author.implicitHeight)
                enabled: root.profilePubkey === ""
                hoverEnabled: enabled
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.openProfile(row.modelData.pubkey)
              }
            }
          }
        }
      }
    }
  }

  // One "LABEL value" line of the profile page; hidden when it has no value.
  // A long value is cut in the middle; clicking it copies the whole of it.
  component DetailRow: Item {
    id: detail
    property string label: ""
    property string value: ""
    property bool openable: false
    readonly property bool justCopied: root.copiedLabel === label

    visible: value !== ""
    width: parent ? parent.width : 0
    implicitHeight: detailValue.implicitHeight

    Text {
      id: detailLabel
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.baseline: detailValue.baseline
      width: Style.space(44)
      text: detail.label.toUpperCase()
      color: root.dim
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
    }

    Text {
      id: detailValue
      textFormat: Text.PlainText
      anchors.left: detailLabel.right
      anchors.right: openGlyph.visible ? openGlyph.left : parent.right
      anchors.rightMargin: openGlyph.visible ? Style.space(8) : 0
      elide: Text.ElideMiddle
      text: detail.justCopied ? "copied" : detail.value
      color: detail.justCopied ? Color.accent
        : (detailArea.containsMouse ? Style.hoverStateColor(root.bar.foreground, Color.accent) : root.bar.foreground)
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.underline: detailArea.containsMouse && !detail.justCopied
    }

    MouseArea {
      id: detailArea
      anchors.fill: detailValue
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.copy(detail.label, detail.value)
    }

    // Opens a web address in the browser.
    Text {
      id: openGlyph
      visible: detail.openable
      textFormat: Text.PlainText
      anchors.right: parent.right
      anchors.baseline: detailValue.baseline
      text: "󰏌"
      color: openArea.containsMouse ? Style.hoverStateColor(root.bar.foreground, Color.accent) : root.dim
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body

      MouseArea {
        id: openArea
        anchors.fill: parent
        anchors.margins: -Style.space(4)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["xdg-open", detail.value])
      }
    }
  }

  // Small outlined button; filled with the accent tint when `highlighted`.
  component ActionChip: Rectangle {
    id: chip
    property string label: ""
    property bool highlighted: false
    signal activated()

    width: chipLabel.implicitWidth + Style.space(18)
    height: chipLabel.implicitHeight + Style.space(8)
    radius: Style.cornerRadius
    color: chipArea.containsMouse ? Style.hoverFillFor(root.bar.foreground, Color.accent)
      : (highlighted ? Qt.alpha(Color.accent, 0.22) : "transparent")
    border.width: 1
    border.color: highlighted ? Qt.alpha(Color.accent, 0.6) : Qt.alpha(root.bar.foreground, 0.25)

    Text {
      id: chipLabel
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: chip.label
      color: chip.highlighted ? Color.accent
        : (chipArea.containsMouse ? Style.hoverStateColor(root.bar.foreground, Color.accent) : root.bar.foreground)
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    MouseArea {
      id: chipArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.activated()
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
      color: root.bar.foreground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Text {
      textFormat: Text.PlainText
      anchors.baseline: counterValue.baseline
      text: parent.label.toUpperCase()
      color: root.dim
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
    }
  }
}
