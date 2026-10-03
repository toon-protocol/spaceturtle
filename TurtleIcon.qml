import QtQuick
import QtQuick.Shapes
import qs.Commons

// Top-down sea turtle, drawn on a 24x24 grid and filled with the theme colour.
// The font's turtle glyph has the same view but evenly sized limbs, so it reads
// as a star at bar size; here the shell dominates and the flippers sweep back.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  // Which drawing to use, 1-5; see `variants`.
  property int variant: 1

  // Each variant: tilt in degrees, then shell, head, front flippers, rear flippers.
  readonly property var variants: [
    // 1: balanced, tilted
    { tilt: 35, paths: [
      "M12 6.5 A6 7.2 0 0 1 12 20.9 A6 7.2 0 0 1 12 6.5 Z",
      "M12 0.8 A2.3 3 0 0 1 12 6.8 A2.3 3 0 0 1 12 0.8 Z",
      "M15.5 8 Q21 7 22.5 11 Q23 14 21.5 16.5 Q20.5 12.5 16.8 11.5 Z",
      "M8.5 8 Q3 7 1.5 11 Q1 14 2.5 16.5 Q3.5 12.5 7.2 11.5 Z",
      "M15.8 17.5 Q18.8 18.5 19.2 22 Q16.5 21.5 14.6 19.8 Z",
      "M8.2 17.5 Q5.2 18.5 4.8 22 Q7.5 21.5 9.4 19.8 Z" ] },
    // 2: big shell, short flippers, upright
    { tilt: 0, paths: [
      "M12 5.5 A7 8 0 0 1 12 21.5 A7 8 0 0 1 12 5.5 Z",
      "M12 0.5 A2.6 3 0 0 1 12 6.5 A2.6 3 0 0 1 12 0.5 Z",
      "M17.5 8 Q22.5 9 22.5 14 Q20.5 11.5 18.6 11 Z",
      "M6.5 8 Q1.5 9 1.5 14 Q3.5 11.5 5.4 11 Z",
      "M17 18.5 Q20 20 19.5 22.5 Q17.5 22 15.8 20.3 Z",
      "M7 18.5 Q4 20 4.5 22.5 Q6.5 22 8.2 20.3 Z" ] },
    // 3: big shell, short flippers, tilted
    { tilt: 35, paths: [
      "M12 5.5 A7 8 0 0 1 12 21.5 A7 8 0 0 1 12 5.5 Z",
      "M12 0.5 A2.6 3 0 0 1 12 6.5 A2.6 3 0 0 1 12 0.5 Z",
      "M17.5 8 Q22.5 9 22.5 14 Q20.5 11.5 18.6 11 Z",
      "M6.5 8 Q1.5 9 1.5 14 Q3.5 11.5 5.4 11 Z",
      "M17 18.5 Q20 20 19.5 22.5 Q17.5 22 15.8 20.3 Z",
      "M7 18.5 Q4 20 4.5 22.5 Q6.5 22 8.2 20.3 Z" ] },
    // 4: hollow shell, tilted
    { tilt: 35, paths: [
      "M12 6.5 A6 7.2 0 0 1 12 20.9 A6 7.2 0 0 1 12 6.5 Z M12 9.2 A3.4 4.5 0 0 0 12 18.2 A3.4 4.5 0 0 0 12 9.2 Z",
      "M12 0.8 A2.3 3 0 0 1 12 6.8 A2.3 3 0 0 1 12 0.8 Z",
      "M15.5 8 Q21 7 22.5 11 Q23 14 21.5 16.5 Q20.5 12.5 16.8 11.5 Z",
      "M8.5 8 Q3 7 1.5 11 Q1 14 2.5 16.5 Q3.5 12.5 7.2 11.5 Z",
      "M15.8 17.5 Q18.8 18.5 19.2 22 Q16.5 21.5 14.6 19.8 Z",
      "M8.2 17.5 Q5.2 18.5 4.8 22 Q7.5 21.5 9.4 19.8 Z" ] },
    // 5: teardrop shell, long wing-like flippers, tilted
    { tilt: 40, paths: [
      "M12 6 Q18.5 8 17.5 15 Q16.5 20 12 22 Q7.5 20 6.5 15 Q5.5 8 12 6 Z",
      "M12 0.8 A2.3 3 0 0 1 12 6.8 A2.3 3 0 0 1 12 0.8 Z",
      "M16 8 Q22 5.5 23.5 12 Q23.5 16 22 18.5 Q21.5 12 17.3 11.5 Z",
      "M8 8 Q2 5.5 0.5 12 Q0.5 16 2 18.5 Q2.5 12 6.7 11.5 Z",
      "M15.5 19 Q17.5 20 17.5 22.5 Q15.5 22 14 20.8 Z",
      "M8.5 19 Q6.5 20 6.5 22.5 Q8.5 22 10 20.8 Z" ] }
  ]
  readonly property var drawing: variants[Math.max(1, Math.min(variants.length, variant)) - 1]

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Shape {
    anchors.fill: parent
    antialiasing: true
    layer.enabled: true
    layer.samples: 4
    layer.smooth: true
    rotation: root.drawing.tilt

    Part { path: root.drawing.paths[0] }
    Part { path: root.drawing.paths[1] }
    Part { path: root.drawing.paths[2] }
    Part { path: root.drawing.paths[3] }
    Part { path: root.drawing.paths[4] }
    Part { path: root.drawing.paths[5] }
  }

  component Part: ShapePath {
    property alias path: svg.path

    fillColor: root.color
    fillRule: ShapePath.OddEvenFill
    strokeWidth: 0
    scale: Qt.size(root.width / 24, root.height / 24)
    PathSvg { id: svg }
  }
}
