# Export simulado (export_occupancy_data()), usado em test-export_occupancy.R
# e test-contract.R

sim_pred <- function() {
  suppressMessages(read_selection_tables(file.path(sim_root(), "tabelas")))
}
sim_recordings <- function() file.path(sim_root(), "gravacoes.csv")
remap <- function() list(remap_from = "N:/Arara/",
                         remap_to = paste0(sim_root(), "/"))

# Revisao simulada: veredito pelo score, sem cortar audio
sim_validation <- function(pred, modo = "random_detections", ...) {
  man <- suppressMessages(do.call(select_clips, c(
    list(pred, modo, threshold = 0.5, recordings = sim_recordings(),
         recording_duration = 180, ...), remap())))
  withr::with_seed(5, {
    p <- ifelse(is.na(man$confidence), 0.5, man$confidence)
    man$verdict <- ifelse(stats::runif(nrow(man)) < p, "positive", "negative")
  })
  man$verdict[1] <- "not_reviewed"
  man
}

export_sim <- function(dir = withr::local_tempdir(.local_envir = parent.frame()),
                       ...) {
  out <- suppressMessages(do.call(export_occupancy_data, c(
    list(dir, sim_pred(), recordings = sim_recordings()), remap(),
    list(...))))
  c(out, dir = dir)
}
