# Reading files in the v1.2.0 format (Portuguese columns and values).
# The map below is the same one documented in NEWS.md and in the contract
# vignette.

#' Map from v1.2.0 (Portuguese) column names to current column names
#' @noRd
legacy_columns <- c(
  # manifest and per-clip review
  local               = "site",
  pasta_especie       = "species_folder",
  data_gravacao       = "recording_date",
  noite               = "night",
  hora_gravacao       = "recording_hour",
  arquivo_clipe       = "clip_file",
  inicio_clipe        = "clip_start",
  fim_clipe           = "clip_end",
  duracao             = "duration",
  audio_origem        = "source_audio",
  begin_path_original = "begin_path",
  modo_amostragem     = "sampling_mode",
  ocasiao_id          = "occasion_id",
  n_deteccoes_ocasiao = "n_detections_occasion",
  prob_inclusao       = "inclusion_prob",
  veredito            = "verdict",
  caminho_wav         = "reviewed_path",
  # recordings table (tabela_gravacoes)
  caminho_audio       = "source_audio",
  # nightly detection history
  especie             = "species",
  n_deteccoes         = "n_detections",
  n_confiaveis        = "n_reliable",
  deteccao_k1         = "detection_k1",
  deteccao_k2         = "detection_k2",
  deteccao_k3         = "detection_k3",
  deteccao            = "detection"
)

#' Map from v1.2.0 (Portuguese) values to current values, by column
#' @noRd
legacy_values <- list(
  verdict = c(positivo = "positive", negativo = "negative",
              nao_validado = "not_reviewed", clipe_ausente = "clip_missing"),
  sampling_mode = c(top = "top", aleatorio_deteccoes = "random_detections",
                    aleatorio_gravacoes = "random_recordings"),
  status = c(ja_existia = "already_exists",
             audio_nao_encontrado = "audio_not_found",
             simulado = "simulated", ok = "ok")
)

#' Test whether a table is in the v1.2.0 format
#'
#' A table is legacy when it has a `local` column and no `site` column.
#'
#' @param df A data frame.
#' @return Logical scalar.
#' @noRd
is_legacy <- function(df) "local" %in% names(df) && !"site" %in% names(df)

#' Convert a v1.2.0 table to the current format
#'
#' Renames columns and recodes values of the v1.2.0 format; tables already
#' in the current format pass unchanged. `clip_file` is NOT changed (the
#' "grav_" prefix of old clips): it is the file name on disk, used to match
#' the review.
#'
#' @param df A data frame, legacy or current.
#' @return A data frame with current column names and values.
#' @noRd
from_legacy <- function(df) {
  if (!is_legacy(df)) return(df)
  old_cols <- intersect(names(legacy_columns), names(df))
  df <- rename(df, !!!setNames(old_cols, legacy_columns[old_cols]))
  for (col in intersect(names(legacy_values), names(df))) {
    value_map <- legacy_values[[col]]
    x <- df[[col]]
    df[[col]] <- ifelse(x %in% names(value_map), unname(value_map[x]), x)
  }
  if ("status" %in% names(df)) {
    df$status <- str_replace(df$status, "^erro: ", "error: ")
  }
  df
}
