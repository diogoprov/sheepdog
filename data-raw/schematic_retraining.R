# Esquema do ciclo de retreino. Rode a partir da raiz do repositorio.
source("data-raw/schematic_icons.R")
xs <- 85 + 150 * 0:4; y <- 40
b <- c(
  icon_headphones(xs[1] - 29, y - 4, 1.15),
  svg_caption(xs[1], y + 86, "Listen", c("to the false", "positives")),
  icon_clip(xs[2] - 22, y + 2, stroke = verde), icon_clip(xs[2] - 22, y + 32, stroke = verde),
  svg_caption(xs[2], y + 86, "retraining_clips()", "confirmed positives"),
  icon_folder(xs[3] - 50, y + 12, 30), icon_folder(xs[3] - 15, y + 12, 30), icon_folder(xs[3] + 20, y + 12, 30, vermelho, vermelho_claro),
  svg_caption(xs[3], y + 86, "build_training_set()", c("train, val, test by night;", "negatives as Noise")),
  icon_loss(xs[4] - 28, y + 6),
  svg_caption(xs[4], y + 86, "Train and re-run", "in BirdNET-Analyzer"),
  icon_clip(xs[5] - 50, y + 16, w = 32, h = 22), icon_clip(xs[5] - 16, y + 16, w = 32, h = 22, crossed = TRUE), icon_clip(xs[5] + 18, y + 16, w = 32, h = 22),
  svg_caption(xs[5], y + 86, "exclude_training_clips()", c("training clips are", "never drawn again")),
  vapply(1:4, \(i) svg_arrow(xs[i] + 56, y + 28, xs[i + 1] - 56, y + 28), ""),
  sprintf('<path d="M%s %s V%s H%s V%s" fill="none" stroke="%s" stroke-width="1.3" stroke-dasharray="5 4"/>',
          xs[5], y + 136, y + 158, xs[1], y + 142, cinza),
  svg_arrow(xs[1], y + 150, xs[1], y + 136, dash = FALSE),
  svg_text(mean(xs[c(1, 5)]), y + 176, "a new random draw, review and diagnostic", 12, cinza))
save_schematic(b, "schematic_retraining", 770, 235)

# A vinheta retraining vai no pacote, e pkgdown/assets nao: copia para vignettes/
file.copy("pkgdown/assets/figures/schematic_retraining.png",
          "vignettes/figures/retraining-loop.png", overwrite = TRUE)
