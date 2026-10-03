import QtQuick
import qs.Commons
import qs.Ui

// The turtle in the bar: a view of the service, one per monitor. A click
// toggles the panel.
BarWidget {
  id: root
  moduleName: "toon.spaceturtle"

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property bool online: service ? service.online : false
  readonly property bool hasUnseen: service ? service.hasUnseen : false
  // Nothing left of today's spending limit.
  readonly property bool urgent: service ? service.urgent : false

  // Inline shell.json setting: { "id": "toon.spaceturtle", "icon": 2 }
  readonly property int iconVariant: Number(setting("icon", 1)) || 1

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function togglePanel() {
    if (bar && bar.shell) bar.shell.toggle(moduleName, "{}")
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
      if (b === Qt.MiddleButton) { if (root.service) root.service.refresh() }
      else root.togglePanel()
    }

    // Unseen-events dot, in the theme's accent; larger while urgent.
    Rectangle {
      visible: root.hasUnseen || root.urgent
      width: root.urgent ? Style.space(7) : Style.space(5)
      height: width
      radius: width / 2
      color: Color.accent
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.rightMargin: Style.space(3)
      anchors.topMargin: Style.space(5)
    }
  }
}
