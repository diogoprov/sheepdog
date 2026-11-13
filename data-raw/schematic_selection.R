# Esquema dos quatro desenhos de select_clips(): a mesma noite de 12 gravacoes.
# Predicoes ilustrativas, as de dev/figures/sampling_designs_svg.py.
# Rode a partir da raiz do repositorio.
source("data-raw/schematic_icons.R")
pred <- list(c(.35, .62), c(.81, .44, .58), numeric(), .28, c(.92, .71),
             c(.52, .33, .66, .47), numeric(), c(.39, .88), .24, c(.57, .74),
             numeric(), c(.31, .49))
limiar <- 0.5
x0 <- 190; cel <- 38; alt <- 56
linha <- function(y, titulo, sub, celula_on, ponto_on) {
  out <- c(svg_text(20, y + 22, titulo, 13, tinta, "start"),
           svg_text(20, y + 40, sub, 11.5, cinza, "start"))
  for (i in seq_along(pred)) {
    x <- x0 + (i - 1) * cel
    out <- c(out, svg_rect(x, y, cel - 5, alt, if (celula_on(i)) azul_claro else "#f4f6f8", rx = 4))
    p <- pred[[i]]
    for (j in seq_along(p)) {
      on <- ponto_on(i, j)
      out <- c(out, svg_dot(x + (cel - 5) * j / (length(p) + 1), y + alt - 4 - p[j] * (alt - 8),
                            if (on) 3.6 else 2.4, if (on) azul else "#b4bcc4"))
    }
  }
  out
}
tem <- function(i) any(pred[[i]] >= limiar)
# predicoes sorteadas em "score_bands": duas por faixa (0.1-0.4, 0.4-0.7, 0.7-1)
faixas <- c("1 1", "9 1", "2 3", "6 4", "5 2", "8 2")
b <- c(
  linha(16, "\"top\"", "highest score per recording",
        function(i) FALSE, function(i, j) pred[[i]][j] == max(pred[[i]])),
  linha(90, "\"random_detections\"", "occasions with a score", function(i) i %in% c(2, 10),
        function(i, j) i %in% c(2, 10)),
  svg_text(20, 146, "above the threshold", 11.5, cinza, "start"),
  linha(164, "\"random_recordings\"", "any recording, even empty", function(i) i %in% c(3, 6, 9),
        function(i, j) i %in% c(3, 6, 9)),
  linha(238, "\"score_bands\"", "random clips per score band", function(i) FALSE,
        function(i, j) paste(i, j) %in% faixas),
  svg_text(20, 294, "thresholds, calibration", 11.5, cinza, "start"),
  svg_text(x0 + 16, 312, "18h", 11, cinza), svg_text(x0 + 11.5 * cel, 312, "05h", 11, cinza))
save_schematic(b, "schematic_selection", 660, 324)
