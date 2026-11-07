# Esquema das rodadas de revisao. Rode a partir da raiz do repositorio.
source("data-raw/schematic_icons.R")
set.seed(4)
n <- 60; ordem <- sample(n)
pool <- function(x, y, r1 = integer(), r2 = integer()) {
  i <- seq_len(n) - 1
  px <- x + (i %% 10) * 15; py <- y + (i %/% 10) * 15
  cores <- rep(claro, n); cores[r1] <- azul; cores[r2] <- ocre
  paste(mapply(svg_dot, px, py, MoreArgs = list(r = 5), fill = cores), collapse = "")
}
r1 <- ordem[1:8]; r2 <- ordem[9:16]
b <- c(
  pool(40, 30, r1), svg_caption(107, 150, "Round 1", c("candidates.csv keeps", "the pool")),
  svg_arrow(196, 68, 250, 68),
  pool(270, 30, r1, r2), svg_caption(337, 150, "select_clips(previous = )", c("what was reviewed", "leaves the pool")),
  svg_arrow(426, 68, 480, 68),
  svg_text(500, 50, "8 + 8 of 60", 13, tinta, "start"),
  svg_text(500, 72, "inclusion_prob = 16/60", 11.5, cinza, "start"),
  svg_caption(570, 150, "combine_rounds()", c("one simple random", "sample of the pool")))
save_schematic(b, "schematic_rounds", 680, 195)
