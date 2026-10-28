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
  sampling_mode = c("top", "random_detections", "random_recordings"),
  occasion_unit = c("file", "minute"),
  threshold = NULL,
  n_top = 2,
  strata = "night_hour",
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
  seed = 2026
)
```

## Arguments

- detections:

  Predictions, as returned by
  [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md).

- sampling_mode:

  `"top"`, `"random_detections"` or `"random_recordings"`. See *Sampling
  modes*.

- occasion_unit:

  The occasion of the occupancy model: `"file"` (the whole recording) or
  `"minute"` (minute of the file, from `file_offset`).

- threshold:

  Confidence threshold of the occupancy analysis. It defines the
  candidate occasions of `"random_detections"` and the
  `n_detections_occasion` column. `NULL` leaves that column `NA`.

- n_top:

  `"top"`: predictions kept per site x species x night x hour.
  `"random_detections"`: occasions drawn per stratum (`strata`).

- strata:

  `"random_detections"`: the strata of the occasion draw (ignored by the
  other modes). Either one of the presets, all within site x species:

  - `"night_hour"`: night x hour (the rule of 2.0.0);

  - `"night"`: night;

  - `"hour"`: hour of the day, pooling the nights (covers the diel cycle
    without fixing the night);

  - `"week"`: ISO week of the night (`YYYY-Www`);

  - `"month"`: month of the night (`YYYY-MM`), which spreads the draw
    over the season;

  - `"site_species"`: no further stratification;

  or a character vector of column names of `detections`, e.g.
  `c("site", "species_code", "habitat", "night")`, for strata defined by
  the user. Columns can be added to `detections` before the call; since
  site and species are always part of the strata, useful columns vary
  within a site (the moon phase, the rain of the night, a recorder when
  a site has several). `month` and `week` can also be used and are
  derived from the night when absent. `site` and `species_code` are
  always added to the strata, which keeps `inclusion_prob` exact when
  `target_total` or `max_per_species` draw again within site x species.
  Columns that depend on the score (`confidence`, `rank`) are refused,
  since the observation-confirmation design needs strata independent of
  the score, and every stratum column must be constant within an
  occasion.

  With one recording per hour and `occasion_unit = "file"`,
  `"night_hour"` holds a single occasion per stratum and draws nothing
  (every `inclusion_prob` is 1); a coarser stratum makes the draw
  random. With strata without the hour and `balance_by_hour = TRUE`
  under `target_total` or `max_per_species`, `inclusion_prob` is
  conditional on the first draw (a warning says so).

- covariates:

  `"random_detections"`: optional data frame of occasion covariates
  whose columns can be used in `strata`, such as the bins of an
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

  `"random_recordings"`: fraction of the recordings (or minutes) drawn
  at each site, rounded, with at least one per site. The default (1 %)
  suits large projects: with fewer than 150 recordings per site it draws
  a single recording; raise it or use `n_recordings_per_site` in small
  projects.

- n_recordings_per_site:

  `"random_recordings"`: fixed number of recordings (or minutes) per
  site, used instead of `recording_fraction`.

- recordings:

  `"random_recordings"`: the list of all recordings, as a data frame or
  the path to a CSV file with the columns `site` and `source_audio` (the
  v1.2.0 columns `local` and `caminho_audio` are also read). `NULL`
  lists the files matching `audio_pattern` in the audio folders that
  appear in `begin_path`; folders without any prediction are then left
  out.

- audio_pattern:

  Regular expression for the audio files listed when `recordings` is
  `NULL`.

- recording_duration:

  Length of the recordings (s), for `occasion_unit = "minute"` in
  `"random_recordings"` and for the end of whole-recording clips. `NULL`
  reads each file with the 'av' package when needed (minute occasions)
  and leaves `clip_end` as `NA` otherwise.

- min_confidence:

  Minimum confidence of a candidate prediction in `"top"`. `NULL`
  applies no filter. The random modes use `threshold`.

- sites:

  Restrict to these sites. `NULL` keeps all.

- date_start, date_end:

  Date window of the recordings (`"YYYYMMDD"`). `NULL` leaves that side
  open.

- species:

  Restrict to these short species codes (the last part of
  `species_code`, e.g. `"boa-ran"`). `NULL` keeps all.

- hour_start, hour_end:

  Hour window (0-23). It can cross midnight:
  `hour_start = 17, hour_end = 2` keeps 17h-23h and 0h-2h, and the
  grouping becomes by night (small hours count as the night before).
  `NULL` applies no filter.

- alternate_days:

  Keep alternate days (or nights), anchored on the first date of each
  site.

- target_total:

  Total clips per site, split evenly among species by water filling:
  species with fewer clips than the quota enter whole and the surplus
  goes to the others. In `"random_detections"` it counts occasions.
  Ignored in `"random_recordings"`. `NULL` sets no target. Because the
  target is split evenly, rare species have higher inclusion
  probabilities than common ones: estimates pooled across species must
  weight the clips by `1 / inclusion_prob`.

- balance_by_hour:

  Within each species, draw round-robin across the hours of the day
  (covers the diel cycle) when applying `target_total` or
  `max_per_species`.

- max_per_species:

  Simpler alternative to `target_total`: a fixed limit per site x
  species. Ignored when `target_total` is set.

- remap_from, remap_to:

  Replace the prefix `remap_from` of the `begin_path` paths by
  `remap_to`, e.g. `"N:/"` and `"/Volumes/Arara/"`. Backslashes are
  turned into forward slashes first.

- seed:

  Seed of every random draw. The global random number generator is left
  as it was.

## Value

A tibble, the clip manifest without `status`, with the columns `site`,
`species_code`, `species_folder`, `recording_date`, `night`,
`recording_hour`, `rank`, `confidence`, `clip_file`, `clip_start`,
`clip_end`, `duration`, `source_audio`, `begin_path`, `sampling_mode`,
`occasion_id`, `n_detections_occasion` and `inclusion_prob`. See
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

In both random modes, use the same `threshold` as the occupancy
analysis.
