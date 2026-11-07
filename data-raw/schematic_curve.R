# Esquema da calibracao: dos clipes revisados a P(tp) de cada deteccao.
# Valores ilustrativos. Rode a partir da raiz do repositorio.
source("data-raw/schematic_icons.R")
set.seed(3)
x0 <- 50; x1 <- 270; yb <- 150; yt <- 30
s <- sort(runif(46)); tp <- rbinom(46, 1, plogis(9 * (s - 0.5)))
pontos <- paste(mapply(svg_dot, x0 + s * (x1 - x0), ifelse(tp == 1, yt - 6, yb + 6) + runif(46, -3, 3),
                       MoreArgs = list(r = 2.6), fill = ifelse(tp == 1, verde, vermelho)), collapse = "")
cut <- 0.5 + qlogis(.95) / 9
xa <- 370; xb <- 590
barras <- character()
alt <- c(40, 52, 60, 48, 66, 44, 58, 40, 50, 36, 44, 30, 38, 26, 34, 22, 28, 24, 18, 22) * .9
for (i in seq_along(alt)) {
  on <- (i - .5) / 20 >= cut
  barras <- c(barras, svg_rect(xa + (i - 1) * 11, yb - alt[i], 9, alt[i], if (on) ocre else claro, rx = 1))
}
b <- c(
  svg_line(x0, yb, x1, yb), svg_line(x0, yt, x0, yb), pontos,
  svg_logistic(x0, x1, yb, yt),
  svg_text(x0 - 10, yt + 5, "1", 11, cinza, "end"), svg_text(x0 - 10, yb + 4, "0", 11, cinza, "end"),
  svg_caption(160, 186, "fit_calibration()", "reviewed clips, true or false, give the curve"),
  svg_arrow(290, 92, 350, 92),
  svg_logistic(xa, xb, yb - 76, yt - 22, stroke = "#c9b48a", width = 1.5),
  svg_line(xa + cut * 220, yt - 22, xa + cut * 220, yb, ocre, 1.2, "4 3"),
  svg_line(xa, yb, xb, yb), paste(barras, collapse = ""),
  svg_text(xa + cut * 220 - 6, yt - 8, "P(tp) = p_min", 11, ocre, "end"),
  svg_caption(480, 186, "score_detections()", "every detection gets its P(tp), reviewed or not"))
save_schematic(b, "schematic_curve", 640, 216)
