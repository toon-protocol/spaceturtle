import QtQuick
import QtQuick.Shapes
import qs.Commons

// Top-down sea turtle as retro pixel art: each drawing is a 16x16 grid, one
// square per "#", filled with the theme colour and drawn with hard edges. The
// font's turtle glyph has evenly sized limbs, so it reads as a star at bar
// size; here the shell dominates and the flippers stand out.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  // Which drawing to use, 1-5; see `variants`.
  property int variant: 1

  // Each variant: 16 rows of 16, head at the top.
  readonly property var variants: [
    // 1: scutes on the shell; the logo
    [ "......####......",
      ".....######.....",
      ".....######.....",
      "......####......",
      ".###.######.###.",
      "################",
      "##.##########.##",
      "#..###.##.###..#",
      "...##########...",
      "...#.##..##.#...",
      "...##########...",
      "...###.##.###...",
      "..############..",
      ".###.######.###.",
      ".##...####...##.",
      ".......##......." ],
    // 2: plain shell
    [ "......####......",
      ".....######.....",
      ".....######.....",
      "......####......",
      ".###.######.###.",
      "################",
      "##.##########.##",
      "#..##########..#",
      "...##########...",
      "...##########...",
      "...##########...",
      "...##########...",
      "..############..",
      ".###.######.###.",
      ".##...####...##.",
      ".......##......." ],
    // 3: hollow shell
    [ "......####......",
      ".....######.....",
      ".....######.....",
      "......####......",
      ".###.######.###.",
      "######....######",
      "##.##......##.##",
      "#..#........#..#",
      "...#........#...",
      "...#........#...",
      "...#........#...",
      "...#........#...",
      "..###......###..",
      ".###.######.###.",
      ".##...####...##.",
      ".......##......." ],
    // 4: long flippers
    [ "......####......",
      ".....######.....",
      ".....######.....",
      "......####......",
      "####.######.####",
      "################",
      "#.############.#",
      "#..##########..#",
      "#..##.####.##..#",
      "...##########...",
      "...##.####.##...",
      "...##########...",
      "....########....",
      "..##.######.##..",
      ".##...####...##.",
      ".......##......." ],
    // 5: compact, for a small bar
    [ "................",
      "......####......",
      ".....######.....",
      "......####......",
      "..##.######.##..",
      ".##############.",
      ".##.########.##.",
      "....########....",
      "....########....",
      "....########....",
      "....########....",
      ".##.########.##.",
      ".##############.",
      "..##..####..##..",
      ".......##.......",
      "................" ]
  ]
  readonly property var drawing: variants[Math.max(1, Math.min(variants.length, variant)) - 1]

  // The drawing as one SVG path: a rectangle for each run of "#" in a row.
  function pathOf(rows) {
    var path = ""
    for (var y = 0; y < rows.length; y++) {
      var row = rows[y]
      var x = 0
      while (x < row.length) {
        if (row[x] !== "#") { x++; continue }
        var start = x
        while (x < row.length && row[x] === "#") x++
        path += "M" + start + " " + y + " h" + (x - start) + " v1 h-" + (x - start) + " Z "
      }
    }
    return path
  }

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Shape {
    anchors.fill: parent
    // Hard edges: a pixel drawing must not be smoothed.
    antialiasing: false
    smooth: false

    ShapePath {
      fillColor: root.color
      strokeWidth: -1
      scale: Qt.size(root.width / 16, root.height / 16)
      PathSvg { path: root.pathOf(root.drawing) }
    }
  }
}
