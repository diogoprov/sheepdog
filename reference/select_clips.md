# Select the clips to validate

Applies the sampling design to the predictions read by
[`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md)
and returns the clip manifest: one row per clip to cut, with its site,
species, night, source audio, start and end. No audio is read or
written; cut the clips with
[`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md).

## Usage

``` r
select_clips(
  detections,
  sampling_mode = c("top", "random_detections", "random_recordings", "score_bands"),
  occasion_unit = c("file", "minute"),
  threshold = NULL,
  n_top = 2,
  strata = "night_hour",
  score_breaks = c(0.1, 0.4, 0.7, 1),
  covariates = NULL,
  recording_fraction = 0.01,
  n_recordings_per_site = NULL,
  recordings = NULL,
  audio_pattern = "\\.(wav|flac|mp3)$",
  recording_duration = NULL,
  min_confidence = 0.1,
  sites = NULL,
  date_start = NULL,
  date_end = NULL,
  species = NULL,
  hour_start = NULL,
  hour_end = NULL,
  alternate_days = FALSE,
  target_total = NULL,
  balance_by_hour = TRUE,
  max_per_species = NULL,
  remap_from = NULL,
  remap_to = NULL,
  seed = 2026,
  previous = NULL,
  candidates = NULL,
  cells = NULL,
  inherit = FALSE
)
```

## Arguments

- detections:

  A data frame of predictions, one row per BirdNET prediction, as
  returned by
  [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md)
  (columns `site`, `begin_path`, `begin_time`, `end_time`,
  `file_offset`, `confidence` and `species_code`).

- sampling_mode:

  Character scalar, one of `"top"`, `"random_detections"`,
  `"random_recordings"` or `"score_bands"`. See *Sampling modes* and
  *Which design for which use*.

- occasion_unit:

  Character scalar, the occasion of the occupancy model: `"file"` (the
  whole recording) or `"minute"` (minute of the file, from
  `file_offset`).

- threshold:

  `NULL` or numeric scalar in \[0, 1\], confidence threshold of the
  occupancy analysis. It defines the candidate occasions of
  `"random_detections"` and the `n_detections_occasion` column. `NULL`
  leaves that column `NA`.

- n_top:

  Integer scalar \>= 1. `"top"`: predictions kept per site x species x
  night x hour. `"random_detections"`: occasions drawn per stratum
  (`strata`). `"score_bands"`: predictions drawn per stratum and score
  band.

- strata:

  Character scalar (a preset name) or character vector (column names).
  `"random_detections"` and `"score_bands"`: the strata of the draw
  (within each, `"score_bands"` also splits by score band) (ignored by
  the other modes). Either one of the presets, all within site x
  species:

  - `"night_hour"`: night x hour (the rule of 2.0.0);

  - `"night"`: night;

  - `"hour"`: hour of the day, pooling the nights (covers the diel cycle
    without fixing the night);

  - `"week"`: ISO week of the night (`YYYY-Www`);

  - `"month"`: month of the night (`YYYY-MM`), which spreads the draw
    over the season;

  - `"site_species"`: no further stratification;

  - `"species"` (`"score_bands"` only): the species alone, pooling the
    sites, for a threshold of the species when the cut per site x band
    would be too coarse (with 60 sites and 3 bands, the smallest step is
    180 clips); `inclusion_prob` is then the share drawn among the
    predictions of the species in the band;

  or a character vector of column names of `detections`, e.g.
  `c("site", "species_code", "habitat", "night")`, for strata defined by
  the user. Columns can be added to `detections` before the call; since
  site and species are always part of the strata, useful columns vary
  within a site (the moon phase, the rain of the night, a recorder when
  a site has several). `month` and `week` can also be used and are
  derived from the night when absent. Except for `"species"`, `site` and
  `species_code` are always added to the strata, which keeps
  `inclusion_prob` exact when `target_total` or `max_per_species` draw
  again within site x species. Columns that depend on the score
  (`confidence`, `rank`) are refused, since the observation-confirmation
  design needs strata independent of the score, and every stratum column
  must be constant within an occasion.

  With one recording per hour and `occasion_unit = "file"`,
  `"night_hour"` holds a single occasion per stratum and draws nothing
  (every `inclusion_prob` is 1); a coarser stratum makes the draw
  random. With strata without the hour and `balance_by_hour = TRUE`
  under `target_total` or `max_per_species`, `inclusion_prob` is
  conditional on the first draw (a warning says so).

- score_breaks:

  Numeric vector of length \>= 2, strictly increasing, within 0 and 1.
  `"score_bands"`: the limits of the score bands. Predictions below the
  first limit are not drawn; the last band includes its upper limit.

- covariates:

  `NULL` or a data frame of occasion covariates. `"random_detections"`:
  its columns can be used in `strata`, such as the bins of an
  environmental gradient or of an acoustic index made by
  [`covariate_bins()`](https://provetelab.org/sheepdog/reference/covariate_bins.md).
  It is joined to the predictions by the columns it shares with them
  among `site`, `night`, `recording_date`, `recording_hour`,
  `source_audio` and `occasion_id` (compared as character; `night` and
  `recording_date` are `YYYYMMDD`). Occasions without a match form a
  stratum of their own, with a warning. A stratum other than site,
  species and time may be related to the verdict, so the calibration
  should include it or weight the clips by `inclusion_prob` (a message
  says so).

- recording_fraction:

  Numeric scalar in \[0, 1\]. `"random_recordings"`: fraction of the
  recordings (or minutes) drawn at each site, rounded, with at least one
  per site. The default (1 %) suits large projects: with fewer than 150
  recordings per site it draws a single recording; raise it or use
  `n_recordings_per_site` in small projects.

- n_recordings_per_site:

  `NULL` or integer scalar \>= 1. `"random_recordings"`: fixed number of
  recordings (or minutes) per site, used instead of
  `recording_fraction`.

- recordings:

  `NULL`, a data frame (one row per recording) or a character scalar,
  path to a CSV file. `"random_recordings"`: the list of all recordings,
  with the columns `site` and `source_audio` (the v1.2.0 columns `local`
  and `caminho_audio` are also read). `NULL` lists the files matching
  `audio_pattern` in the audio folders that appear in `begin_path`;
  folders without any prediction are then left out.

- audio_pattern:

  Character scalar, regular expression for the audio files listed when
  `recordings` is `NULL`.

- recording_duration:

  `NULL` or numeric scalar, length of the recordings (s), for
  `occasion_unit = "minute"` in `"random_recordings"` and for the end of
  whole-recording clips. `NULL` reads each file with the 'av' package
  when needed (minute occasions) and leaves `clip_end` as `NA`
  otherwise.

- min_confidence:

  `NULL` or numeric scalar in \[0, 1\], minimum confidence of a
  candidate prediction in `"top"`. `NULL` applies no filter. The random
  modes use `threshold`.

- sites:

  `NULL` or character vector of site names. Restrict to these sites (the
  predictions and, in `"random_recordings"`, the list of recordings).
  `NULL` keeps all.

- date_start, date_end:

  `NULL` or character scalars, date window of the recordings
  (`"YYYYMMDD"`). `NULL` leaves that side open.

- species:

  `NULL` or character vector. Restrict to these short species codes (the
  last part of `species_code`, e.g. `"boa-ran"`). `NULL` keeps all.

- hour_start, hour_end:

  `NULL` or integer scalars in 0-23, hour window. It can cross midnight:
  `hour_start = 17, hour_end = 2` keeps 17h-23h and 0h-2h, and the
  grouping becomes by night (small hours count as the night before).
  `NULL` applies no filter.

- alternate_days:

  Logical scalar. If `TRUE`, keep alternate days (or nights), anchored
  on the first date of each site.

- target_total:

  `NULL` or integer scalar \>= 1, total clips per site, split evenly
  among species by water filling: species with fewer clips than the
  quota enter whole and the surplus goes to the others. In
  `"random_detections"` it counts occasions. Ignored in
  `"random_recordings"`. `NULL` sets no target. Because the target is
  split evenly, rare species have higher inclusion probabilities than
  common ones: estimates pooled across species must weight the clips by
  `1 / inclusion_prob`.

- balance_by_hour:

  Logical scalar. If `TRUE`, within each species, draw round-robin
  across the hours of the day (covers the diel cycle) when applying
  `target_total` or `max_per_species`.

- max_per_species:

  `NULL` or integer scalar \>= 1. Simpler alternative to `target_total`:
  a fixed limit per site x species. Ignored when `target_total` is set.

- remap_from, remap_to:

  `NULL` or character scalars. Replace the prefix `remap_from` of the
  `begin_path` paths by `remap_to`, e.g. `"N:/"` and
  `"/Volumes/Arara/"`. Backslashes are turned into forward slashes
  first.

- seed:

  Integer scalar, seed of every random draw. The global random number
  generator is left as it was.

- previous:

  `NULL`, a character vector of paths, a data frame, or a list of these.
  Earlier reviews: paths to their `clip_manifest.csv` or
  `validation_by_clip.csv`, or their tables. Rounds of the same design
  give another round (see Review rounds); reviews of the other random
  design, which need `validation_by_clip.csv`, give their verdicts (see
  Reusing the other design).

- candidates:

  `NULL`, a character scalar (path) or a data frame. With `previous`,
  the `candidates.csv` of the first round. `NULL` looks for it in the
  folders of `previous`.

- cells:

  `NULL` or a data frame, one row per cell. With `previous`, restrict
  the round to these cells: a data frame with `site` and
  `species_folder` or `species_code`, such as the rows of
  [`review_support()`](https://provetelab.org/sheepdog/reference/review_support.md)
  with `diagnosis == "review more"`.

- inherit:

  Logical scalar. With `previous` of the other design, give the clips
  the verdict that the earlier review implies, so that they need no
  review. See Reusing the other design.

## Value

A tibble, the clip manifest without `status`, with the columns `site`,
`species_code`, `species_folder`, `recording_date`, `night`,
`recording_hour`, `rank`, `confidence`, `clip_file`, `clip_start`,
`clip_end`, `duration`, `source_audio`, `begin_path`, `sampling_mode`,
`occasion_id`, `n_detections_occasion`, `inclusion_prob` (cumulative
over the rounds), `round`, `n_candidates` (`N` of the stratum),
`n_drawn` (occasions drawn in the stratum, all rounds so far; both `NA`
outside `"random_detections"` and under a cap) and
`inclusion_prob_round` (the draw of that round alone),
`previously_reviewed`, `inherited_verdict` and `source_design` (see
Reusing the other design). See
[`vignette("crywolf-integration")`](https://provetelab.org/sheepdog/articles/crywolf-integration.md)
for their definitions.

## Sampling modes

- `"top"` keeps the `n_top` predictions with the highest confidence per
  site x species x night x hour. It serves classifier retraining and the
  score-to-probability calibration of
  [`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md).
  Do not use it to estimate false-positive rates: top-score clips hold
  fewer false positives than a random sample.

- `"random_detections"` draws, at random, `n_top` occasions per stratum
  (by default site x species x night x hour; see `strata`) among the
  occasions with at least one prediction of the species with confidence
  \>= `threshold`, and keeps every prediction \>= `threshold` of each
  drawn occasion. This is the observation-confirmation design of
  Chambert et al. (2015,
  [doi:10.1890/14-1507.1](https://doi.org/10.1890/14-1507.1) ).

- `"random_recordings"` draws recordings (or minutes) among all those
  recorded, with or without predictions, in proportion to the effort of
  each site, for annotation by ear. This is the multiple-method design
  of Miller et al. (2011,
  [doi:10.1890/10-1396.1](https://doi.org/10.1890/10-1396.1) ). The clip
  is the whole recording (or minute), copied once per species to
  annotate, and `confidence` is `NA`.

- `"score_bands"` draws, at random, `n_top` predictions per stratum and
  score band (`score_breaks`, by default 0.1 to 0.4, 0.4 to 0.7 and 0.7
  to 1), with `inclusion_prob = n_drawn / n_candidates` in each stratum
  x band. The same number of clips per band covers the whole score
  range, which is where a threshold and a calibration curve are
  estimated, and the weights `1 / inclusion_prob` restore the true
  proportions when bands are pooled (Wood & Kahl 2024,
  [doi:10.1007/s10336-024-02144-5](https://doi.org/10.1007/s10336-024-02144-5)
  ).

In the random modes, use the same `threshold` as the occupancy analysis.

## Which design for which use

The draw decides what the reviewed clips can be used for:

|  |  |  |  |  |
|----|----|----|----|----|
| Use | `"top"` | `"random_detections"` | `"random_recordings"` | `"score_bands"` |
| retraining the classifier | yes | yes | yes | yes |
| calibration curve ([`calibrate()`](https://provetelab.org/sheepdog/reference/calibrate.md), [`fit_calibration()`](https://provetelab.org/sheepdog/reference/fit_calibration.md)) | high scores only | yes | no score | yes, best near the threshold |
| threshold by weighted precision ([`suggest_thresholds()`](https://provetelab.org/sheepdog/reference/suggest_thresholds.md)) | no (no `inclusion_prob`) | yes | no score | yes |
| false-positive occupancy models (crywolf) | dropped | yes | yes (annotated occasions) | **no** |

The clips of `"score_bands"` are chosen by their score, so they cannot
estimate the false-positive rate of the observation-confirmation design,
which needs clips chosen independently of the score:
[`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
writes them to `validation.csv` with a warning, and
[`crywolf::fp_read_sheepdog()`](https://provetelab.org/crywolf/reference/fp_read_sheepdog.html)
drops them with a warning, or stops when they are the only reviewed
clips. For both uses in one project, draw a `"random_detections"` round
for the occupancy model and a `"score_bands"` round for the threshold; a
clip drawn by both is reviewed once (`previous`, `inherit`).

## Review rounds

`previous` draws one more round of a design without repeating what was
reviewed. In `"random_detections"`, the occasions drawn earlier leave
the pool and `n_top` occasions are drawn per stratum among the rest.
Drawing `n1` occasions of `N` and then `n2` of the `N - n1` left gives a
simple random sample of `n1 + n2`, so after each round every clip has
the inclusion probability `n_drawn / n_candidates`, whatever its round.
This needs the same candidates, strata, threshold and occasion unit in
every round. The first round therefore keeps a list of its candidates,
in the attribute `"candidates"` of the manifest, written to
`candidates.csv` by
[`extract_validation_clips()`](https://provetelab.org/sheepdog/reference/extract_validation_clips.md);
later rounds draw from that list, and a warning says when the
predictions have changed. A different `threshold`, `occasion_unit` or
`strata` is refused, and so are `target_total` and `max_per_species`,
whose second stage depends on the counts of each round. Round `k` uses
the seed `seed + k - 1`.

The tables of earlier rounds keep the probability of their own round:
use
[`combine_rounds()`](https://provetelab.org/sheepdog/reference/combine_rounds.md)
to stack them. In `"top"`, there is no inclusion probability, and
`previous` only leaves out the clips already reviewed. `previous` is not
available for `"random_recordings"`, and a `"score_bands"` round has no
later rounds of its own; to add clips near the threshold after
`"random_detections"` rounds, draw a `"score_bands"` round with those
rounds as `previous` of the other design, and stack all of them with
[`combine_rounds()`](https://provetelab.org/sheepdog/reference/combine_rounds.md),
which keeps the `inclusion_prob` of the `"score_bands"` clips.

Choosing the cells of a round from their verdicts, and stopping when a
cell reaches a target, makes the stopping depend on the results; see
[`vignette("validation-effort")`](https://provetelab.org/sheepdog/articles/validation-effort.md).

## Reusing the other design

A study can draw both `"random_detections"` and `"random_recordings"`.
With `previous` of the other design, the occasions reviewed there stay
in the pool, so that this draw remains independent and its inclusion
probabilities do not change, and `previously_reviewed` marks the clips
that overlap an earlier review, matching site, species, recording and
time, so that minutes and files can be mixed. With `inherit = TRUE`,
what the earlier review already tells is reused:

|  |  |  |  |
|----|----|----|----|
| Earlier review | This draw | Inherited | Still to review |
| recording absent | `"random_detections"` | every prediction is negative | nothing |
| recording present | `"random_detections"` | nothing | the clips |
| a positive prediction | `"random_recordings"` | the recording is present | nothing |
| only negative predictions | `"random_recordings"` | nothing | the recording |

The species may have called below the threshold, so negative predictions
say nothing about the recording.
[`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md)
skips the clips with an `inherited_verdict`, the review app leaves them
out, and
[`post_validation()`](https://provetelab.org/sheepdog/reference/post_validation.md)
fills them in, so that the table of each design is complete for its
precision and thresholds.
[`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
leaves them out: an inherited verdict is the same judgement as the
earlier one, and exporting it would give a model two observations of it.

`inherit` is `FALSE` by default because of that last step. The occasions
left out are chosen by their verdict (present recordings, negative
clips), which can bias what an occupancy model estimates from those
tables. The overlap between two random draws is usually small, so
reviewing it costs little; use `inherit = TRUE` when the tables will not
go to an occupancy model.
