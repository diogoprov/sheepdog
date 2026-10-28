#' @keywords internal
"_PACKAGE"

#' @import dplyr
#' @import purrr
#' @import stringr
#' @import tidyr
#' @importFrom readr read_csv read_tsv write_csv
#' @importFrom stats setNames
#' @importFrom tibble tibble
NULL

# Colunas usadas via tidy evaluation (evita NOTEs do R CMD check)
utils::globalVariables(c(
  "n_high", "n_fp", "n_high_all", "prec_high", "unreviewed_high",
  "diagnosis",
  ".g", ".confiavel", "pr_reliable", "p_tp_lower", "draw", "max_rhat",
  "min_ess_bulk", "min_ess_tail", "n_divergent", "n", 
  ".N", ".dur", ".dia", ".n", ".ordem", ".p1", ".p2", "begin_path",
  "begin_time", "clip_end", "clip_start", "confidence", "duration",
  "end_time",
  "file_offset", "hour_int", "inclusion_prob", "n_detections_occasion",
  "night", "occasion_id", "pasta", "rank", "recording_date", "status",
  "recording_hour", "site", "source_audio", "species_code",
  "species_folder", "bin", "clip_file", "conf_meio", "low_support", "n_positive",
  "n_reviewed", "reviewed_path", "subpasta", "verdict", ".treino",
  "Confidence", "Species Code", "Begin Path", "File Offset (s)",
  "auc_mean", "date", "detection_k1", "detection_k2", "detection_k3",
  ".fold_id", "faixa", "fold", "hour", "logit_conf", "n_reliable", "p_tp", "prec",
  "species", "tp", "included", "month", "n_nights_detected",
  "n_nights_recorded", "frequency", "logloss_mean", "prop_singular",
  "complexity", "model", "set", "class_folder", "t_ini", "t_fim", ".linha",
  "n_tp", "min_confidence", "max_confidence", "threshold", "reason", "ok",
  "any_reliable", "reviewer", "second_reviewer", ".r1", ".r2", ".dupla",
  ".veredito", "n_reviewers", "to", "start", "sampling_mode", "grid_index", "group", "observed",
  "pred_mean", "pred_lower", "pred_upper", "p_value", "flagged",
  ".n_scores"
))
