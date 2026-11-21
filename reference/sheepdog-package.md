# sheepdog: sample, validate and calibrate BirdNET detections

sheepdog draws clips of BirdNET predictions for manual review,
summarises the verdicts, calibrates the confidence scores into
probabilities of true detection and builds detection histories and
community matrices from them. Start with
[`vignette("sheepdog")`](https://provetelab.org/sheepdog/articles/sheepdog.md).

## Glossary

The terms below are used with these meanings throughout the
documentation and the vignettes.

- **Prediction** or **detection**: one row of a BirdNET selection table,
  a species code with a confidence score for a time window of a
  recording.

- **Confidence** or **score**: the BirdNET output in (0, 1). It is not a
  probability that the prediction is correct until calibrated.

- **Verdict**: the outcome of the manual review of a clip, `"positive"`
  (true positive, TP) or `"negative"` (false positive, FP).

- **Precision**: the share of the reviewed predictions above a score
  threshold that are true positives, TP / (TP + FP). Weighted precision
  weights each clip by `1 / inclusion_prob`.

- **Occasion**: the sampling unit of the random designs and of the
  occupancy export, one recording (`occasion_unit = "file"`) or one
  minute of a recording (`"minute"`); see
  [`vignette("crywolf-integration")`](https://provetelab.org/sheepdog/articles/crywolf-integration.md).

- **Inclusion probability** (`inclusion_prob`): the probability that a
  clip or occasion was drawn, `n_drawn / n_candidates` within its
  stratum and score band. Weights `1 / inclusion_prob` make the drawn
  units stand for all the candidates.

- **Recall ceiling**: the share of the occasions in which a species
  called (by manual annotation of whole recordings) that have at least
  one prediction of it above `min_confidence`; no threshold recovers
  more (see
  [`recall_ceiling()`](https://provetelab.org/sheepdog/reference/recall_ceiling.md)).

- **P(TP)**: the probability that a prediction is a true positive,
  predicted by a calibration model from its score, species and site.

- **Calibration model**: a logistic regression of the verdicts on the
  logit of the score, `logit_conf`, with species and site effects (see
  [`calibration_models()`](https://provetelab.org/sheepdog/reference/calibration_models.md)
  and
  [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)).

- **Calibration intercept and slope**: the coefficients of a logistic
  regression of held-out verdicts on the logit of the predicted P(TP). A
  well calibrated model has intercept 0 and slope 1; a slope below 1
  means probabilities that are too extreme.

- **`p_min`**: the P(TP) above which a detection is taken as reliable
  when detection histories are built.

- **Detection history**: for each site, species and night, whether the
  species was detected by at least `min_detections_night` reliable
  detections (see
  [`detection_history()`](https://provetelab.org/sheepdog/reference/detection_history.md)).

- **R-hat, bulk and tail ESS**: convergence diagnostics of a Bayesian
  fit, the potential scale reduction factor and the effective sample
  sizes of the centre and of the tails of the posterior (see
  [`calibration_diagnostics()`](https://provetelab.org/sheepdog/reference/calibration_diagnostics.md)).

## Option arguments

Arguments that take one of a set of strings (such as `engine`,
`sampling_mode` or `occasion_unit`) are case-sensitive. Most are matched
with [`match.arg()`](https://rdrr.io/r/base/match.arg.html), which also
accepts unambiguous partial matches: `engine = "brms"` and
`engine = "b"` work, but `engine = "BRMS"` raises an error listing the
allowed values. The others are compared exactly, without partial
matching.

## See also

Useful links:

- <https://github.com/diogoprov/sheepdog>

- <https://provetelab.org/sheepdog/>

- Report bugs at <https://github.com/diogoprov/sheepdog/issues>

## Author

**Maintainer**: Diogo B. Provete <dbprovete@gmail.com>
([ORCID](https://orcid.org/0000-0002-0097-0651)) \[copyright holder\]

Authors:

- Diogo B. Provete <dbprovete@gmail.com>
  ([ORCID](https://orcid.org/0000-0002-0097-0651)) \[copyright holder\]

- Larissa Sayuri Moreira Sugai
  ([ORCID](https://orcid.org/0000-0002-6248-291X)) \[copyright holder\]

- Liliana Piatti ([ORCID](https://orcid.org/0000-0001-6324-1723))
  \[copyright holder\]
