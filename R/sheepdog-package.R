#' @keywords internal
"_PACKAGE"

#' @import dplyr
#' @import purrr
#' @import stringr
#' @import tidyr
#' @importFrom readr col_character cols read_csv read_tsv type_convert
#'   write_csv
#' @importFrom stats setNames
#' @importFrom tibble tibble
NULL

# Colunas usadas via tidy evaluation (evita NOTEs do R CMD check)
utils::globalVariables(c(
  "present", "max_score",
  "score_band", ".limiar", ".sorteada", "below_target", "n_above", "precision_above",
  "arquivo", "hours_with_detections", "n_det", "n_detections",
  "n_windows", "neg", "pos", "threshold_lower",
  "n_reliable", "confidence_max", "species_folder",
  ".a", ".b", ".ini", ".fim", ".linha", ".rec", ".negativo", ".desenho",
  ".todos_neg", ".algum_pos", "inherited_verdict",
  "thr_empirical", "prec_empirical", "n_support", "thr_model_precision",
  "thr_p_tp", "p_tp_at_threshold", "model_precision_at_empirical",
  "max_reviewed", "above_reviewed", "flag", "precision_used",
  "precision_weighted_at_threshold", "precision_at_threshold", "threshold",
  ".cell", ".env", ".entrada", ".estrato", ".pr", ".inicio", ".esperado", ".n_antes", ".n_agora", ".antes",
  "stratum", "n_candidates", "n_drawn", "n_rounds", "sampling_mode",
 "n_high", "n_fp", "n_high_all", "prec_high", "unreviewed_high",
  "diagnosis", ".sp", ".rodada", ".desempate", "recording", "time",
  ".g", ".p", "mista", ".confiavel", "pr_reliable", "p_tp_lower", "draw", "max_rhat",
  "min_ess_bulk", "min_ess_tail", "n_divergent", "n", 
  ".N", ".dur", ".dia", ".n", ".ordem", ".p1", ".p2", "begin_path",
  "begin_time", "clip_end", "clip_start", "confidence", "duration",
  "end_time",
  "file_offset", "hour_int", "inclusion_prob", "n_detections_occasion",
  "night", "occasion_id", "pasta", "rank", "recording_date", "status",
  "recording_hour", "site", "source_audio", "species_code",
  "species_folder", "bin", "clip_file", ".id", ".certeza", ".ids", ".k",
  "identity_one", ".peso", ".n_classe", "n_weighted", "identity", "identity_certainty", "conf_meio", "low_support", "n_positive",
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
  ".n_scores", "n_occasions", "inclusion_prob_unit", "drawn", "size_used", ".arquivo"
))
