import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The floating window: six sections, one number key each, all views of the
// service. The shell loads this when the panel is summoned and unloads it when
// it closes, so what must outlive a close (section, cursor) is on the service.
Item {
  id: root

  // Injected by the shell.
  property var shell: null
  property var service: null

  readonly property string pluginId: "toon.spaceturtle"
  // Read by the shell to decide what `toggle` does.
  readonly property bool opened: window.visible
  property bool closingFromHost: false

  readonly property color dim: Qt.darker(Color.foreground, 1.5)

  // In key order: section n is opened by number key n.
  readonly property var sections: ["Activity", "Network", "Messages", "Requests", "Node", "Persona"]
  readonly property int activitySection: 1
  readonly property int networkSection: 2
  readonly property int messagesSection: 3
  readonly property int nodeSection: 5
  readonly property int section: service ? service.section : activitySection
  // The section that has a cursor to move, if the one showing does.
  readonly property var cursorSection: section === activitySection ? activity.item
    : (section === networkSection ? network.item : (section === nodeSection ? node.item : null))

  function open(payloadJson) {
    closingFromHost = false
    window.visible = true
    if (service) service.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  // Closed by the shell (`shell hide`, or the toggle): it already knows.
  function close() {
    closingFromHost = true
    window.visible = false
    closingFromHost = false
  }

  // Closed from here (Esc): tell the shell, so its next toggle opens the panel.
  function requestClose() {
    if (shell) shell.hide(pluginId)
    else window.visible = false
  }

  function showSection(number) {
    if (service && number >= 1 && number <= sections.length) service.section = number
  }

  // Esc: back within the section, and out of the panel from its top level.
  function back() {
    if (!cursorSection || !cursorSection.back()) requestClose()
  }

  function syncLooking() {
    if (service) service.looking = window.visible
  }

  onServiceChanged: syncLooking()
  Component.onDestruction: if (service) service.looking = false

  FloatingWindow {
    id: window
    // Hyprland window rules match on this; see the README.
    title: "Spaceturtle"
    color: Color.background
    implicitWidth: Style.space(560)
    implicitHeight: Style.space(720)
    minimumSize: Qt.size(Style.space(380), Style.space(320))

    onVisibleChanged: {
      root.syncLooking()
      // Closed by Hyprland: the shell has not been told yet.
      if (!visible && !root.closingFromHost && root.shell) root.shell.hide(root.pluginId)
    }

    FocusScope {
      anchors.fill: parent
      focus: true

      PanelKeyCatcher {
        id: keyCatcher
        anchors.fill: parent
        onMoveRequested: function(dx, dy) {
          if (!root.cursorSection) return
          if (dy !== 0) root.cursorSection.move(dy)
          else if (dx < 0) root.cursorSection.back()
          else root.cursorSection.activate()
        }
        onActivateRequested: if (root.cursorSection) root.cursorSection.activate()
        onCloseRequested: root.back()
        onTabRequested: function(direction) {
          var count = root.sections.length
          root.showSection((root.section - 1 + direction + count) % count + 1)
        }
        onTextKey: function(text) {
          if (Number(text) >= 1 && Number(text) <= root.sections.length) root.showSection(Number(text))
          else if (text === "r") { if (root.service) root.service.refresh() }
          else if (root.cursorSection) root.cursorSection.key(text)
        }

        Column {
          id: head
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Style.spacing.panelPadding
          spacing: Style.spacing.panelGap

          SectionTabs {
            width: parent.width
            names: root.sections
            current: root.section
            onSelected: function(number) { root.showSection(number) }
          }

          PanelSeparator {}
        }

        Item {
          anchors.top: head.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.margins: Style.spacing.panelPadding

          // Waits for the service, so the section never has to ask whether it has one.
          Loader {
            id: activity
            anchors.fill: parent
            active: root.service !== null
            visible: root.section === root.activitySection
            sourceComponent: ActivitySection { service: root.service }
          }

          Loader {
            id: network
            anchors.fill: parent
            active: root.service !== null
            visible: root.section === root.networkSection
            sourceComponent: NetworkSection { service: root.service }
          }

          Loader {
            id: node
            anchors.fill: parent
            active: root.service !== null
            visible: root.section === root.nodeSection
            sourceComponent: NodeSection { service: root.service }
          }

          // The sections that are still to be built; and a panel with no service.
          Text {
            visible: (root.section !== root.activitySection && root.section !== root.networkSection && root.section !== root.nodeSection) || !root.service
            anchors.centerIn: parent
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: !root.service ? "The spaceturtle service is not running. Run: omarchy restart shell"
              : (root.section === root.messagesSection ? "Private messages are locked." : "Nothing here yet.")
            color: root.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.italic: true
          }
        }
      }
    }
  }
}
