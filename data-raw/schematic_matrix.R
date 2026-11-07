# Esquema do Stage 3: historico, matriz e ordenacao. Valores ilustrativos.
# Rode a partir da raiz do repositorio.
source("data-raw/schematic_icons.R")
set.seed(2)
h <- matrix(rbinom(40, 1, .5), 5)
m <- matrix(c(.9,.2,.6,.4, .3,.8,.1,.7, .6,.5,.9,.2, .1,.7,.3,.8), 4, byrow = TRUE)
px <- c(462,482,500,520,540,558,474,548); py <- c(90,58,76,48,92,62,44,40)
b <- c(
  svg_grid(36, 34, h, 15, 3, verde),
  svg_caption(106, 150, "Nightly history", "species x night"),
  svg_arrow(196, 78, 246, 78),
  svg_grid(260, 34, m, 20, 3, verde),
  svg_caption(306, 150, "community_matrices()", c("nights with detection /", "nights recorded")),
  svg_arrow(376, 78, 430, 78),
  svg_line(450, 110, 575, 110), svg_line(450, 30, 450, 110),
  paste(mapply(svg_dot, px, py, MoreArgs = list(r = 4, fill = verde)), collapse = ""),
  svg_caption(512, 150, "vegan or gllvm", "ordination of the sites"))
save_schematic(b, "schematic_matrix", 620, 196)
