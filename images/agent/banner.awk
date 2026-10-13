# Makes the film docker-agent plays where its own banner would be (--banner-file): the turtle
# of docs/assets/spaceturtle-banner-dark.svg, with its two strokes and that banner's colours,
# flying through a field of stars large enough to fill the chat of a large terminal. The chat
# shows the middle of it, so the stars reach every edge whatever the terminal's size.
# Two squares of the picture go to a character, a frame lasts a tenth of a second and a form
# feed parts the frames. The field is 240 squares wide and 128 high. The near stars move a
# square a frame; the far ones move a square every second frame and their half of the field
# is laid twice side by side, so the film closes on itself after 240 frames.
# The stars are scattered by a fixed rule, as thickly as in the README's banner, so every
# build makes the same film. The turtle takes the terminal's own colour, so it shows on a
# light one as on a dark one.
function rnd(n) { seed = (seed * 1103515245 + 12345) % 2147483648; return int(seed / 65536) % n }
function px(x, y) {
  if (stroke ? ((x, y) in tb) : ((x, y) in ta)) return 1
  if (((x + t) % W, y) in near) return 2
  if (((x + int(t / 2)) % (W / 2), y) in far) return 3
  return 0
}
BEGIN { W = 240; H = 128; seed = 57 }
/<g / { g++ }
# The turtle's squares, moved from the middle of the README's banner to the middle of the field.
/<rect / && g > 2 {
  split($0, q, "\"")
  for (j = 0; j < q[6]; j++) {
    x = q[2] + j + (W - 128) / 2; y = q[4] + (H - 24) / 2
    if (g == 3) ta[x, y]; else tb[x, y]
  }
}
END {
  for (i = 0; i < W / 2 * H * 26 / (128 * 24); i++) far[rnd(W / 2), rnd(H)]
  for (i = 0; i < W; i++) blank = blank " "
  for (i = 0; i < W * H * 14 / (128 * 24); i++) { x = rnd(W); y = rnd(H); near[x, y]; near[(x + 1) % W, y] }
  fg[1] = "\033[39m"; fg[2] = "\033[38;2;170;182;224m"; fg[3] = "\033[38;2;86;98;143m"
  bg[2] = "\033[48;2;170;182;224m"; bg[3] = "\033[48;2;86;98;143m"
  for (t = 0; t < W; t++) {
    stroke = int(t / 4) % 2
    if (t) print "\f"
    for (r = 0; r < H / 2; r++) {
      line = ""; ink = 0; gap = 0
      for (x = 0; x < W; x++) {
        u = px(x, 2 * r); d = px(x, 2 * r + 1)
        if (!u && !d) { gap++; continue }
        line = line substr(blank, 1, gap); gap = 0
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
