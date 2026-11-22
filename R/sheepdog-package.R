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

# Columns used through tidy evaluation (avoids R CMD check NOTEs)
utils::globalVariables(c(
  ".a", ".b", ".bin", ".cand_stratum", ".cell", ".confuser", ".day",
  ".design", ".drawn", ".dur", ".end", ".env", ".expected", ".file",
  ".fold_id", ".g", ".id", ".ids", ".input", ".k", ".len", ".n", ".N",
  ".n_before", ".n_class", ".n_now", ".negative", ".order", ".p", ".p1",
  ".p2", ".pair", ".pr", ".prior", ".r1", ".r2", ".reliable", ".round",
  ".sp", ".start", ".stratum", ".thr", ".tiebreak", ".train", ".ts",
  ".verdict", ".weight", "above_reviewed", "any_reliable", "auc_mean",
  "Begin Path", "begin_path", "begin_time", "below_target", "bin",
  "bin_mid", "class_folder", "classified_by", "clip_end", "clip_file",
  "clip_start", "complexity", "confidence", "Confidence", "curve",
  "cv_logloss", "cv_logloss_se", "deployment_media", "deploymentID",
  "detail", "detection_k1", "detection_k2", "detection_k3", "diagnosis",
  "draw", "drawn", "duration", "end_time", "File Offset (s)",
  "file_offset", "flag", "flagged", "fold", "folder", "fp", "frequency",
  "grid_index", "group", "high_freq", "hour", "hour_int",
  "hours_with_detections", "identity_certainty", "identity_one",
  "included", "inclusion_prob", "inclusion_prob_unit", "inherited_verdict",
  "level", "logloss_mean", "low_freq", "low_support", "lower",
  "max_confidence", "max_p", "max_reviewed", "max_rhat", "media_id",
  "mediaID", "min_ess_bulk", "min_ess_tail", "mixed", "model",
  "model_precision_at_empirical", "month", "n_above", "n_candidates",
  "n_checked", "n_det", "n_detections", "n_detections_occasion",
  "n_divergent", "n_drawn", "n_fp", "n_high", "n_high_all",
  "n_nights_detected", "n_nights_recorded", "n_occasions", "n_positive",
  "n_raised", "n_reliable", "n_reviewed", "n_reviewers", "n_rounds",
  "n_support", "n_tp", "n_weighted", "n_windows", "neg", "night",
  "observation_id", "observed", "occasion_id", "ok", "p", "p_tp",
  "p_tp_at_threshold", "p_tp_lower", "p_value", "pos", "pr_reliable",
  "prec", "prec_empirical", "prec_high", "precision_above",
  "precision_at_threshold", "precision_used",
  "precision_weighted_at_threshold", "pred_lower", "pred_mean",
  "pred_upper", "prop_singular", "reason", "recording", "recording_date",
  "recording_hour", "reviewed_path", "reviewer", "sampling_mode",
  "scientific_name", "score_band", "second_reviewer", "set", "sign1",
  "sign1_ceiling", "sign2", "sign2_tp_kept", "sign6", "sign6_detail",
  "sign6_fp_spread", "sign7", "sign7_detail", "sign7_share_below", "sign8",
  "sign8_verdict", "sign9", "sign9_deff", "site", "source_audio",
  "species", "Species Code", "species_code", "species_folder", "start",
  "status", "stratum", "t_end", "t_start", "thr_empirical",
  "thr_model_precision", "thr_p_tp", "threshold", "threshold_lower",
  "threshold_p_tp", "threshold_precision", "threshold_weighted", "time",
  "to", "top_error", "top_error_excess", "tp", "unreviewed_high", "upper",
  "verdict", "w"
))
