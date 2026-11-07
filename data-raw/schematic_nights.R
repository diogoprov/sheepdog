# Esquema das noites: deteccoes de uma noite e historico. Valores ilustrativos.
# Rode a partir da raiz do repositorio.
source("data-raw/schematic_icons.R")
x0 <- 40; x1 <- 290; yb <- 130; yt <- 26
p <- c(.2, .97, .55, .98, .4, .99, .7, .3)
xs <- x0 + (seq_along(p) - .5) * (x1 - x0) / length(p)
cab <- character()
for (i in seq_along(p)) {
  y <- yb - p[i] * (yb - yt); on <- p[i] >= .95
  cab <- c(cab, svg_line(xs[i], yb, xs[i], y, if (on) ocre else "#b4bcc4", 1.5),
           svg_dot(xs[i], y, 4.2, if (on) ocre else "#ffffff", if (on) ocre else "#9aa4ae"))
}
hist <- matrix(c(1,1,0,1,0,1,1,0,1,
                 0,1,1,0,1,1,0,1,0,
                 1,1,1,0,1,1,1,1,1,
                 0,0,1,0,0,0,1,0,0), 4, byrow = TRUE)
nomes <- c("boa_ran", "den_nan", "sci_nas", "pse_pla")
b <- c(
  svg_line(x0, yb, x1, yb), svg_line(x0, yt + 3, x1, yt + 3, cinza, 1, "4 3"),
  svg_text(x1 + 4, yt + 7, "p_min", 11, cinza, "start"), paste(cab, collapse = ""),
  svg_text(x0, yb + 16, "18h", 11, cinza, "start"), svg_text(x1, yb + 16, "05h", 11, cinza, "end"),
  svg_caption(165, 172, "One night of boa_ran", "3 detections reach p_min, so k = 1, 2 and 3 all pass"),
  svg_arrow(346, 80, 396, 80),
  vapply(1:4, \(i) svg_text(470, 48 + (i - 1) * 21, nomes[i], 11.5, tinta, "end"), ""),
  svg_grid(480, 36, hist, cell = 17, gap = 4, cor = ocre),
  svg_rect(478, 34, 21, 21, "none", tinta, 3),
  svg_caption(560, 172, "detection_history()", "one row per site x species x night"))
save_schematic(b, "schematic_nights", 690, 200)
