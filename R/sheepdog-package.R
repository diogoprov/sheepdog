#' sheepdog: sample, validate and calibrate BirdNET detections
#'
#' sheepdog draws clips of BirdNET predictions for manual review,
#' summarises the verdicts, calibrates the confidence scores into
#' probabilities of true detection and builds detection histories and
#' community matrices from them. Start with `vignette("sheepdog")`.
#'
#' @section Glossary:
#' The terms below are used with these meanings throughout the
#' documentation and the vignettes.
#'
#' * **Prediction** or **detection**: one row of a BirdNET selection
#'   table, a species code with a confidence score for a time window of a
#'   recording.
#' * **Confidence** or **score**: the BirdNET output in (0, 1). It is not
#'   a probability that the prediction is correct until calibrated.
#' * **Verdict**: the outcome of the manual review of a clip, `"positive"`
#'   (true positive, TP) or `"negative"` (false positive, FP).
#' * **Precision**: the share of the reviewed predictions above a score
#'   threshold that are true positives, TP / (TP + FP). Weighted precision
#'   weights each clip by `1 / inclusion_prob`.
#' * **Occasion**: the sampling unit of the random designs and of the
#'   occupancy export, one recording (`occasion_unit = "file"`) or one
#'   minute of a recording (`"minute"`); see
#'   `vignette("crywolf-integration")`.
#' * **Inclusion probability** (`inclusion_prob`): the probability that a
#'   clip or occasion was drawn, `n_drawn / n_candidates` within its
#'   stratum and score band. Weights `1 / inclusion_prob` make the drawn
#'   units stand for all the candidates.
#' * **Recall ceiling**: the share of the occasions in which a species
#'   called (by manual annotation of whole recordings) that have at least
#'   one prediction of it above `min_confidence`; no threshold recovers
#'   more (see [recall_ceiling()]).
#' * **P(TP)**: the probability that a prediction is a true positive,
#'   predicted by a calibration model from its score, species and site.
#' * **Calibration model**: a logistic regression of the verdicts on the
#'   logit of the score, `logit_conf`, with species and site effects (see
#'   [calibration_models()] and [fit_calibration()]).
#' * **Calibration intercept and slope**: the coefficients of a logistic
#'   regression of held-out verdicts on the logit of the predicted P(TP).
#'   A well calibrated model has intercept 0 and slope 1; a slope below 1
#'   means probabilities that are too extreme.
#' * **`p_min`**: the P(TP) above which a detection is taken as reliable
#'   when detection histories are built.
#' * **Detection history**: for each site, species and night, whether the
#'   species was detected by at least `min_detections_night` reliable
#'   detections (see [detection_history()]).
#' * **R-hat, bulk and tail ESS**: convergence diagnostics of a Bayesian
#'   fit, the potential scale reduction factor and the effective sample
#'   sizes of the centre and of the tails of the posterior (see
#'   [calibration_diagnostics()]).
#'
#' @section Option arguments:
#' Arguments that take one of a set of strings (such as `engine`,
#' `sampling_mode` or `occasion_unit`) are case-sensitive. Most are
#' matched with `match.arg()`, which also accepts unambiguous partial
#' matches: `engine = "brms"` and `engine = "b"` work, but `engine =
#' "BRMS"` raises an error listing the allowed values. The others are
#' compared exactly, without partial matching.
#'
#' @section Input tables and missing values:
#' Every function that takes a table accepts a `data.frame`, a tibble or a
#' `data.table` and converts it to a tibble on entry, so the result does not
#' depend on the class of the input. Numeric columns lose extra classes
#' (such as those of the 'units' package) and list columns among the
#' columns a function uses raise an error.
#'
#' Rows with a missing value in a column a function needs (the score and
#' the audio path of a prediction; the variables of a calibration formula;
#' the score of a clip reviewed with `"top"`, `"random_detections"` or
#' `"score_bands"`) are left out with a message that says how many. Set
#' `options(sheepdog.missing = "error")` to stop with an error instead.
#' Missing values are never imputed. A reviewed clip without a score is
#' not a missing value when it comes from `"random_recordings"` (whole
#' recordings have no score); when a table of reviewed clips has no
#' `sampling_mode` column, every clip without a score is taken as such a
#' recording and left out of the precision and the thresholds without a
#' message.
#'
#' @srrstats {G2.14, G2.14a, G2.14b} The section "Input tables and missing
#'   values" documents the option `sheepdog.missing` ("omit" or "error").
#' @srrstats {G1.3} The section "Glossary" defines the statistical terms
#'   used in the package.
#' @srrstats {G2.3b} The section "Option arguments" documents that option
#'   strings are case-sensitive.
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
  "mediaID", "deploymentID", "momento", "duracao", "media_id", "deployment_media",
  "deployment_id", "observation_id", "scientific_name", "classified_by",
  "low_freq", "high_freq", "lower", "upper",
  "sign1_ceiling", "sign2_tp_kept", "sign6_fp_spread", "sign6_detail",
  "sign7_share_below", "sign7_detail", "sign8_verdict", "sign1", "sign2",
  "sign6", "sign7", "sign8", "sign9", "sign9_deff", "n_checked", "n_raised",
  "nivel", "spread",
  "detail", "grupo", "identity", "fp", ".confuser",
  "present", "max_score",
  "faixa", "tp", "w", "observed", "curve", "max_p", "threshold_p_tp",
  "threshold_precision", "threshold_weighted", "cv_logloss", "cv_logloss_se",
  "top_error", "top_error_excess", "p",
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
