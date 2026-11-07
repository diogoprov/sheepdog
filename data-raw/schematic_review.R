# Esquema da revisao: clipes, ouvir, pastas. Rode a partir da raiz do repositorio.
source("data-raw/schematic_icons.R")
clipes <- c(icon_clip(40, 40), icon_clip(96, 40), icon_clip(40, 76), icon_clip(96, 76),
            icon_clip(68, 112))
b <- c(clipes,
  svg_caption(103, 168, "cut_clips()", "the clips of the manifest"),
  svg_arrow(158, 88, 228, 88),
  icon_headphones(250, 56, 1.15),
  svg_caption(279, 168, "BirdNET GUI or run_app()", "you listen and decide"),
  svg_arrow(330, 74, 420, 50), svg_arrow(330, 102, 420, 126),
  icon_folder(432, 26, 46, verde, verde_claro), icon_folder(432, 106, 46, vermelho, vermelho_claro),
  svg_text(490, 50, "Positive", 13, verde, "start"),
  svg_text(490, 130, "Negative", 13, vermelho, "start"),
  svg_caption(470, 168, "", "one verdict per clip"))
save_schematic(b, "schematic_review", 590, 195)
