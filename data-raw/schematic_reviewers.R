# Esquema de varios revisores. Rode a partir da raiz do repositorio.
source("data-raw/schematic_icons.R")
b <- c(
  icon_clip(62, 30), icon_clip(62, 62), icon_clip(62, 94),
  svg_caption(84, 158, "assign_reviewers()", "a share goes to both"),
  svg_arrow(124, 62, 210, 50), svg_arrow(124, 88, 210, 108),
  icon_person(224, 22, .95), svg_text(270, 50, "A", 13, azul, "start"),
  icon_person(224, 86, .95, ocre, ocre_claro), svg_text(270, 114, "B", 13, ocre, "start"),
  svg_caption(248, 158, "split_by_reviewer()", "each hears their own"),
  svg_arrow(292, 50, 386, 72), svg_arrow(292, 108, 386, 86),
  svg_grid(400, 56, matrix(c(1, .25, .25, 1), 2), cell = 22, gap = 3),
  svg_caption(424, 158, "reviewer_agreement()", "kappa on the shared clips"),
  svg_arrow(464, 80, 570, 80),
  icon_clip(584, 40, stroke = verde), icon_clip(584, 72, stroke = vermelho),
  icon_clip(584, 104, stroke = cinza),
  svg_caption(606, 158, "consensus_verdicts()", "disagreements are re-heard"))
save_schematic(b, "schematic_reviewers", 712, 192)
