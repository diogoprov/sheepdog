# =============================================================================
# copy_figures.R
#
# Copia as figuras de pkgdown/assets/figures/ para as vinhetas e os artigos.
# As vinhetas vao para o pacote, entao precisam da copia em vignettes/figures/;
# os artigos, em vignettes/articles/figures/, ficam so no site.
# Rode depois de refazer qualquer figura, a partir da raiz do repositorio.
# =============================================================================
origem <- "pkgdown/assets/figures"

copiar <- function(nomes, destino) {
  ok <- file.copy(file.path(origem, paste0(nomes, ".png")), destino,
                  overwrite = TRUE)
  stopifnot(all(ok))
}

copiar(c("schematic_rounds", "schematic_curve", "schematic_nights",
         "schematic_draws", "schematic_matrix", "stage2_calibration",
         "stage3_community", "score_overlap"),
       "vignettes/figures")
copiar(c("stage1_diagnostic", "schematic_curve", "schematic_nights",
         "schematic_draws", "schematic_review", "schematic_reviewers",
         "thresholds", "occupancy_model", "occupancy_mixture",
         "occupancy_threshold", "occupancy_routes"),
       "vignettes/articles/figures")
