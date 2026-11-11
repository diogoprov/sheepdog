# Directed review round: units drawn with probability proportional to size

Draws a review round aimed at the units where a review is worth most,
while keeping a known inclusion probability for every clip. A unit is a
group of occasions, such as site x month x species. Each unit gets a
size, typically the expected gain of one review predicted by an
occupancy model; `n_units` units are drawn with probability proportional
to size (PPS), one occasion is drawn at random within each drawn unit,
and every prediction of that occasion at or above `threshold` becomes a
clip, as in `sampling_mode = "random_detections"` of
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md).

## Usage

``` r
select_directed(
  detections,
  units,
  n_units,
  threshold,
  size_col = "size",
  floor = 0.05,
  occasion_unit = c("file", "minute"),
  previous = NULL,
  seed = 2026,
  remap_from = NULL,
  remap_to = NULL
)
```

## Arguments

- detections:

  Predictions, as returned by
  [`read_selection_tables()`](https://provetelab.org/sheepdog/reference/read_selection_tables.md).

- units:

  Data frame with one row per eligible unit: the columns that define the
  unit (any columns of the prepared predictions, such as `site`,
  `species_code` and `month`) and the size column. Only listed units are
  drawn, so leave out the units that need no review, for instance those
  where a review has already confirmed the species.

- n_units:

  Number of units to draw.

- threshold:

  Confidence threshold: an occasion is a candidate when it has at least
  one prediction at or above it, and its clips are all such predictions.
  Use the threshold of the occupancy analysis.

- size_col:

  Column of `units` with the size (non-negative).

- floor:

  Share of the mean size added to every size, so that a unit with size 0
  can still be drawn. Without it, a unit the model judges worthless is
  never reviewed and the model is never corrected there.

- occasion_unit:

  The occasion of the occupancy model: `"file"` (the whole recording) or
  `"minute"` (minute of the file, from `file_offset`).

- previous:

  Manifests of earlier review rounds (of any design), as paths or data
  frames. Their clips are left out, matched by recording file and start:
  an occasion is a candidate only while it has a prediction at or above
  `threshold` not yet reviewed.

- seed:

  Seed of the draws. The global random number generator is left as it
  was.

- remap_from, remap_to:

  Replace the prefix `remap_from` of the `begin_path` paths by
  `remap_to`, e.g. `"N:/"` and `"/Volumes/Arara/"`. Backslashes are
  turned into forward slashes first.

## Value

The manifest of the round, with the columns of
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
`sampling_mode = "directed_pps"`, `n_candidates` (\\N_u\\),
`n_drawn = 1` and, at the end, `stratum` (the unit, its values joined by
`|`). The attribute `"units"` holds the units with their size,
`size_used` (after the floor), `n_occasions`, `inclusion_prob_unit` and
`drawn`, for the record of the round; save it next to the manifest.

## Details

**Inclusion probabilities.** With sizes \\x_u\\ (after the floor), the
inclusion probability of unit \\u\\ is \\\pi_u = n x_u / \sum x\\, and
units whose \\\pi_u\\ would exceed 1 are taken with certainty while the
others share the rest of `n_units`. The units are drawn by systematic
PPS sampling in a random order, which gives exactly these \\\pi_u\\. The
occasion is then drawn among the \\N_u\\ candidate occasions of the
unit, so each clip has `inclusion_prob` \\= \pi_u / N_u\\. The round is
conditional on the earlier rounds: `inclusion_prob` is the probability
of this round, given what was reviewed before.

**What the weights support.** Weighted by `1 / inclusion_prob`, the
clips of the round estimate totals and ratios (such as the precision) of
the candidate predictions of the listed units (Horvitz and Thompson
1952,
[doi:10.1080/01621459.1952.10483446](https://doi.org/10.1080/01621459.1952.10483446)
). Systematic PPS has no simple joint inclusion probability, so the
exact design variance is not available; approximations that treat the
draw as with replacement are usually conservative. The units were chosen
by a model, so the round is not a sample of all predictions: an
occupancy model that reads it needs the inclusion probabilities, which
[`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md)
writes.

A unit without candidate occasions (all reviewed, or no prediction at or
above `threshold`) is dropped with a message before the draw.

## See also

[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md),
[`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md),
[`export_occupancy_data()`](https://provetelab.org/sheepdog/reference/export_occupancy_data.md).

## Examples

``` r
if (FALSE) { # \dontrun{
pred <- read_selection_tables("N:/Arara")
units <- readr::read_csv("expected_gain.csv") # site, month, species_code, size
sel <- select_directed(pred, units, n_units = 40, threshold = 0.5,
                       previous = "validation_r1/clip_manifest.csv")
man <- cut_clips(sel, "validation_directed")
readr::write_csv(man, "validation_directed/clip_manifest.csv")
readr::write_csv(attr(sel, "units"), "validation_directed/units.csv")
} # }
```
