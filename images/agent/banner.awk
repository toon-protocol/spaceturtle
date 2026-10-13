# Turns docs/assets/spaceturtle-banner-dark.svg into the frames docker-agent plays where its
# own banner would be (--banner-file): two squares of the picture to a character, a frame
# every tenth of a second, a form feed between frames. The near stars move a square a frame
# and the far ones a square every third frame, so the film closes on itself after 384 frames.
# The turtle takes the terminal's own colour, so it shows on a light one as on a dark one.
function px(x, y) {
  if (stroke ? ((x, y) in tb) : ((x, y) in ta)) return 1
  if (((x + t) % 128, y) in near) return 2
  if (((x + int(t / 3)) % 128, y) in far) return 3
  return 0
}
/<g / { g++ }
/<rect / {
  split($0, q, "\"")
  for (j = 0; j < q[6]; j++) {
    if (g == 1) far[(q[2] + j) % 128, q[4]]; else if (g == 2) near[(q[2] + j) % 128, q[4]]
    else if (g == 3) ta[q[2] + j, q[4]]; else tb[q[2] + j, q[4]]
  }
}
END {
  fg[1] = "\033[39m"; fg[2] = "\033[38;2;170;182;224m"; fg[3] = "\033[38;2;86;98;143m"
  bg[2] = "\033[48;2;170;182;224m"; bg[3] = "\033[48;2;86;98;143m"
  for (t = 0; t < 384; t++) {
    stroke = int(t / 4) % 2
    if (t) print "\f"
    for (r = 0; r < 12; r++) {
      line = ""; ink = 0
      for (x = 32; x < 96; x++) {
        u = px(x, 2 * r); d = px(x, 2 * r + 1)
        if (!u && !d) { line = line " "; continue }
        if (u && d && u != d) {
          if (d == 1) line = line fg[1] bg[u] "▄\033[49m"; else line = line fg[u] bg[d] "▀\033[49m"
          ink = d == 1 ? 1 : u; continue
        }
        c = u ? u : d
        if (c != ink) { line = line fg[c]; ink = c }
        line = line (u && d ? "█" : u ? "▀" : "▄")
      }
      print line
    }
  }
}
