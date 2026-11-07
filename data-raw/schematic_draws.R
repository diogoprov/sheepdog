# Esquema da incerteza com brms. Valores ilustrativos.
# Rode a partir da raiz do repositorio.
source("data-raw/schematic_icons.R")
x0 <- 40; x1 <- 260; yb <- 130
t <- seq(0, 1, length.out = 80); d <- dbeta(t, 16, 4); d <- d / max(d) * 92
px <- x0 + t * (x1 - x0); py <- yb - d
corte <- 0.72; i <- t >= corte
area <- paste(c(sprintf("%.1f,%.1f", px[i][1], yb), sprintf("%.1f,%.1f", px[i], py[i]),
                sprintf("%.1f,%.1f", x1, yb)), collapse = " ")
set.seed(9)
grade <- function() matrix(rbinom(20, 1, .6), 4)
b <- c(
  sprintf('<polygon points="%s" fill="%s"/>', area, ocre_claro),
  sprintf('<polyline points="%s" fill="none" stroke="%s" stroke-width="2"/>',
          paste(sprintf("%.1f,%.1f", px, py), collapse = " "), ocre),
  svg_line(x0, yb, x1, yb), svg_line(x0 + corte * 220, 32, x0 + corte * 220, yb, cinza, 1, "4 3"),
  svg_text(x0 + corte * 220 - 6, 40, "p_min", 11, cinza, "end"),
  svg_caption(150, 160, "P(tp) of one detection", "the shaded share is pr_reliable"),
  svg_arrow(286, 82, 336, 82),
  svg_rect(372, 18, 92, 76, "#ffffff", claro, 4), svg_grid(380, 26, grade(), 13, 2, ocre),
  svg_rect(360, 34, 92, 76, "#ffffff", claro, 4), svg_grid(368, 42, grade(), 13, 2, ocre),
  svg_rect(348, 50, 92, 76, "#ffffff", cinza, 4), svg_grid(356, 58, grade(), 13, 2, ocre),
  svg_caption(410, 160, "history_draws()", "one history per posterior draw"),
  svg_arrow(486, 82, 536, 82),
  svg_grid(548, 44, matrix(c(.9,.4,.7,.2,.6,.8,.3,.5,.9), 3), 22, 3, ocre),
  svg_caption(590, 160, "community_matrices_draws()", "a mean and an interval per cell"))
save_schematic(b, "schematic_draws", 700, 190)
