#' Sample, review and export clips in a local app
#'
#' Opens a 'shiny' app, in the browser, for stages 1 and 2 of the
#' workflow. The tabs depend on the arguments:
#'
#' * **Intro**: a graphical abstract of the sampling designs and an Audio
#'   panel to choose the audio folder, the BirdNET results and the
#'   validation folder (with a dialog of the system), with a summary of the
#'   recordings per site and night. Folders given to `run_app()` are
#'   confirmed when the app opens. Without them, the app opens on this tab.
#' * **Sampling** (with `selection_dir` and `output_dir`): a form for the
#'   sampling design of [select_clips()]. *Draw* shows the clips per site
#'   and species and their inclusion probabilities without touching the
#'   audio; *Cut clips* cuts them with [cut_clips()] and writes
#'   `clip_manifest.csv`, `extraction_info.csv` and `clips/` to
#'   `output_dir`, as [extract_validation_clips()] does (without the zip
#'   packages). The new clips go straight to the Review tab.
#' * **Review**: the clips of a manifest one at a time, with the
#'   spectrogram and a player for each clip, its site, night, hour, score
#'   and design, and buttons to mark it positive, negative or uncertain.
#'   An optional *Identity* field says what a negative or uncertain clip
#'   is: free text, or one or more suggestions (the species of the
#'   manifest and [identity_categories()]), marked *sure* or *probable*.
#'   Fill it before clicking *Negative* or *Uncertain*; it is cleared at
#'   each verdict and ignored for positives.
#'   Each verdict is written at once to `verdicts_file`, so an interrupted
#'   session loses nothing and can be resumed. The tab replaces moving the
#'   clips into `Positive` and `Negative` folders in the BirdNET GUI;
#'   [app_verdicts()] turns `verdicts_file` into the table that
#'   [classify_review()] returns.
#' * **Export** (with `selection_dir` and `output_dir`): calls
#'   [export_occupancy_data()] with the detections of `selection_dir`, the
#'   verdicts of the Review tab (combined by [consensus_verdicts()] when a
#'   clip has several reviewers) and, optionally, `recordings`, and shows
#'   the summary of `schema.json`. The score calibration is not in the app
#'   yet; call [export_occupancy_data()] with `fit` for it.
#'
#' The app runs on the reviewer's computer and reads the clips from disk;
#' nothing is uploaded.
#'
#' @section Keyboard:
#' In the Review tab: `p` positive, `n` negative, `u` uncertain, right
#' arrow next clip, left arrow previous clip, space play or pause.
#'
#' @section Verdicts file:
#' A CSV with one line per click: `clip_file`, `species_folder`,
#' `reviewer`, `verdict` (`"positive"`, `"negative"` or `"uncertain"`) and
#' `time`, then `identity` (several separated by `|`) and
#' `identity_certainty` (`"sure"` or `"probable"`), empty when no identity
#' was given. Lines are only appended; when a clip is marked again, the
#' last verdict of the reviewer counts. Several reviewers can share one
#' file or keep one each. A file of an earlier version, without the
#' identity columns, is rewritten once with them empty at its next verdict.
#'
#' @param manifest `NULL`, a data frame (or tibble) or a character scalar path
#'   to `clip_manifest.csv`: the clip manifest (from [select_clips()],
#'   [cut_clips()] or [assign_reviewers()]), one row per clip. With
#'   `output_dir`, by default `<output_dir>/clip_manifest.csv` when it exists.
#' @param clips_dir `NULL` or a character scalar, folder of the cut clips, with
#'   one subfolder per species (`<clips_dir>/<species_folder>/<clip_file>`, as
#'   written by [cut_clips()]). With `output_dir`, `<output_dir>/clips` by
#'   default.
#' @param verdicts_file `NULL` or a character scalar, path to the CSV (`.csv`)
#'   where the verdicts are written. By default, `verdicts.csv` in `output_dir`
#'   or next to `manifest` when it is a path.
#' @param reviewer `NULL` or a character scalar, name of the reviewer, written
#'   with each verdict. With a manifest from [assign_reviewers()], only the
#'   clips assigned to this reviewer (as first or second reviewer) are shown.
#' @param max_freq `NULL` or a numeric scalar, upper limit of the spectrogram,
#'   in kHz: 12 by default (e.g. `8` for most anuran calls). `NULL` shows the
#'   whole band. It can also be changed in the Review tab.
#' @param selection_dir `NULL` or a character scalar, folder of the BirdNET
#'   selection tables (as in [read_selection_tables()]). Opens the Sampling and
#'   Export tabs.
#' @param output_dir `NULL` or a character scalar, folder of the validation
#'   round: the clips, the manifest, the verdicts and the export
#'   (`<output_dir>/occupancy` by default) are written there.
#' @param recordings `NULL`, a data frame (or tibble) of all recordings (columns
#'   `site` and `source_audio`, one row per recording) or a character scalar
#'   path to its CSV: needed by `"random_recordings"` and, in the export, to
#'   keep the occasions without detections (see [export_occupancy_data()]).
#' @param audio_dir `NULL` or a character scalar, folder of the recordings,
#'   subfolders included. Every recording is listed with [list_recordings()] and
#'   written to the `recordings` CSV when it is a path, or else to
#'   `<output_dir>/recordings.csv`; the list is used as `recordings`. Can also
#'   be chosen in the app (Intro > Audio panel).
#' @param site_pattern `NULL` or a character scalar, regular expression with one
#'   capture group that takes the site from the file names, when the recordings
#'   or the selection tables of several sites share a folder (see
#'   [list_recordings()] and [read_selection_tables()]). Can also be set in the
#'   Audio panel.
#' @param blind Logical scalar. If `TRUE`, blind review: the Review tab hides
#'   the score, the sampling design and the clip file name (which starts with
#'   the score), and shows the clips in an order shuffled once per reviewer
#'   instead of the order of the manifest, so that the verdict does not lean on
#'   the score.
#' @param classifier `NULL` or a character scalar, label of the classifier,
#'   recorded in `extraction_info.csv` and `schema.json`.
#' @param launch.browser Logical scalar: open the app in the browser? Passed to
#'   [shiny::runApp()].
#' @param ... Further arguments to [shiny::runApp()], e.g. `port`.
#'
#' @return Called for its side effect; returns when the app is closed.
#' @seealso [app_verdicts()], `vignette("review-app")`.
#' @export
#' @examples
#' if (interactive()) {
#'   # Review only
#'   run_app("validation/clip_manifest.csv", "validation/clips",
#'           reviewer = "liliana")
#'
#'   # Sample, cut, review and export
#'   run_app(selection_dir = "N:/Arara", output_dir = "validation",
#'           recordings = "recordings.csv", reviewer = "liliana",
#'           max_freq = 8)
#' }
run_app <- function(manifest = NULL, clips_dir = NULL, verdicts_file = NULL,
                    reviewer = NULL, max_freq = 12, selection_dir = NULL,
                    output_dir = NULL, recordings = NULL, audio_dir = NULL,
                    site_pattern = NULL, blind = FALSE, classifier = NULL,
                    launch.browser = interactive(), ...) {
  require_suggested("shiny", "to run the review app")
  require_suggested("av", "to draw the spectrograms")
  if (!is.null(verdicts_file)) {
    verdicts_file <- check_file_ext(verdicts_file, "csv", "verdicts_file")
  }
  if (!is.null(manifest) && is.null(clips_dir) && is.null(output_dir)) {
    stop("Give `clips_dir` with `manifest`, or `output_dir`.", call. = FALSE)
  }
  if (!is.null(manifest) && !is.character(manifest) &&
      is.null(verdicts_file) && is.null(output_dir)) {
    stop("Give `verdicts_file` when `manifest` is a data frame.",
         call. = FALSE)
  }
  st <- app_state(manifest = manifest, clips_dir = clips_dir,
                  verdicts_file = verdicts_file, reviewer = reviewer,
                  max_freq = max_freq, selection_dir = selection_dir,
                  output_dir = output_dir, recordings = recordings,
                  audio_dir = audio_dir, site_pattern = site_pattern,
                  blind = blind, classifier = classifier)
  load_app_state(st)
  if (!is.null(st$clip_queue)) {
    message(nrow(st$clip_queue), " clip(s) to review; verdicts written to ",
            st$verdicts_file, ".")
  }
  shiny::runApp(review_app(st), launch.browser = launch.browser, ...)
}

#' Verdicts of the review app
#'
#' Joins the verdicts written by [run_app()] to the clip manifest, giving
#' the same table as [classify_review()] (the content of
#' `validation_by_clip.csv`), so that the summaries of stage 1, the
#' agreement between reviewers and the calibration work as with a review
#' in the BirdNET GUI. `"uncertain"` verdicts are kept but, like
#' `"disagreement"`, left out of precision, thresholds and calibration,
#' which use only positive and negative verdicts.
#'
#' A clip marked more than once by the same reviewer keeps the last
#' verdict; a message says how many clips were marked again and how many of
#' them changed verdict.
#'
#' @inheritParams run_app
#' @param verdicts_file Character scalar, path to the CSV written by
#'   [run_app()].
#' @param clips_dir `NULL` or a character scalar, folder of the clips, to fill
#'   `reviewed_path` (needed by [build_training_set()]).
#' @param reviewer `NULL` or a character scalar, the reviewer: only their
#'   verdicts are used. With `NULL`, every reviewer's verdicts are kept, one row
#'   per clip and reviewer, ready for [reviewer_agreement()] and
#'   [consensus_verdicts()].
#'
#' @return A tibble (class `tbl_df`): the manifest with `verdict`
#'   (`"positive"`, `"negative"`,
#'   `"uncertain"` or `"not_reviewed"`), `reviewed_path`, `reviewer`,
#'   `identity` and `identity_certainty` (`NA` when the reviewer gave no
#'   identity, or with a verdicts file of an earlier version).
#'   With `reviewer = NULL`, a clip reviewed by two reviewers has two
#'   rows, and a clip not yet reviewed has one row with `reviewer = NA`.
#' @seealso [run_app()], [classify_review()].
#' @examples
#' man <- system.file("extdata", "clip_manifest.csv", package = "sheepdog")
#' m <- read.csv(man)
#' # A verdicts file as written by run_app(), with two reviewers
#' f <- tempfile(fileext = ".csv")
#' write.csv(data.frame(
#'   clip_file = m$clip_file[c(1, 1, 2, 3)],
#'   species_folder = m$species_folder[c(1, 1, 2, 3)],
#'   reviewer = c("ana", "bruno", "ana", "bruno"),
#'   verdict = c("positive", "negative", "positive", "uncertain"),
#'   time = "2026-01-15T20:00:00-0300"
#' ), f, row.names = FALSE)
#' # The verdicts of one reviewer
#' v <- app_verdicts(man, f, reviewer = "ana")
#' table(v$verdict)
#' # Every reviewer: one row per clip and reviewer
#' v_all <- app_verdicts(man, f)
#' v_all[!is.na(v_all$reviewer), c("clip_file", "reviewer", "verdict")]
#' @export
app_verdicts <- function(manifest, verdicts_file, clips_dir = NULL,
                         reviewer = NULL) {
  check_string(verdicts_file, "verdicts_file")
  check_string(clips_dir, "clips_dir", null_ok = TRUE)
  check_string(reviewer, "reviewer", null_ok = TRUE)
  man <- read_manifest(manifest)
  log <- read_verdict_log(verdicts_file, last_only = FALSE)
  if (!is.null(reviewer)) log <- log[log$reviewer %in% reviewer, ]
  report_remarked(log)
  log <- last_verdicts(log)
  extra <- setdiff(log$clip_file, man$clip_file)
  if (length(extra) > 0) {
    warning(length(extra), " clip(s) of `verdicts_file` are not in the ",
            "manifest and were left out.", call. = FALSE)
  }
  log <- select(log, clip_file, species_folder, reviewer, verdict,
                all_of(identity_columns))
  key <- intersect(c("clip_file", "species_folder"), names(man))
  base <- select(man, -any_of(c("verdict", "reviewed_path",
                                "reviewer", "second_reviewer",
                                identity_columns)))
  out <- left_join(base, log[c(key, "reviewer", "verdict",
                               identity_columns)], by = key,
                   relationship = "one-to-many") |>
    mutate(verdict = replace_na(verdict, "not_reviewed"),
           reviewed_path = if (is.null(clips_dir)) NA_character_ else
             file.path(clips_dir, species_folder, clip_file))
  out <- fill_inherited(out)
  if (!is.null(reviewer)) out$reviewer <- reviewer
  counts <- count(out, verdict)
  message("Clips in the review queue: ", nrow(man), "\n",
          paste0("  ", counts$verdict, ": ", counts$n, collapse = "\n"))
  out
}

#' Report clips marked more than once by the same reviewer
#'
#' @param log A data frame of verdicts, all lines, from
#'   `read_verdict_log(last_only = FALSE)`.
#' @return A tibble with one row per clip x reviewer and columns `n`
#'   (times marked) and `n_verdicts` (distinct verdicts), invisibly;
#'   messages how many clips were marked again.
#' @noRd
report_remarked <- function(log) {
  marks <- log |>
    group_by(clip_file, species_folder, reviewer) |>
    summarise(n = n(), n_verdicts = n_distinct(verdict), .groups = "drop")
  n_remarked <- sum(marks$n > 1)
  if (n_remarked > 0) {
    message(n_remarked, " clip(s) marked more than once by the same ",
            "reviewer, ", sum(marks$n_verdicts > 1), " of them with ",
            "different verdicts; the last verdict counts.")
  }
  invisible(marks)
}

#' Build the review queue of the app
#'
#' Keeps the clips of the reviewer (with a manifest from
#' assign_reviewers()) and adds the path of each clip.
#'
#' @param manifest A data frame or character scalar path to the manifest.
#' @param clips_dir Character scalar, folder of the cut clips.
#' @param reviewer Character scalar or `NULL`, the reviewer.
#' @param blind Logical scalar; if `TRUE`, shuffles the clips with
#'   `blind_order()`.
#' @return The manifest rows to review, with column `path`.
#' @noRd
review_queue <- function(manifest, clips_dir, reviewer = NULL,
                         blind = FALSE) {
  queue <- read_manifest(manifest)
  queue <- queue[!is_inherited(queue), ]
  check_columns(queue, c("clip_file", "species_folder"), "manifest")
  if (!is.null(reviewer) && "reviewer" %in% names(queue)) {
    second <- if ("second_reviewer" %in% names(queue)) {
      queue$second_reviewer %in% reviewer
    } else {
      FALSE
    }
    queue <- queue[queue$reviewer %in% reviewer | second, ]
    if (nrow(queue) == 0) {
      stop("No clip of the manifest is assigned to reviewer `", reviewer,
           "`.", call. = FALSE)
    }
  }
  for (col in c("site", "night", "recording_hour", "confidence",
                "sampling_mode", "species_code")) {
    if (!col %in% names(queue)) queue[[col]] <- NA
  }
  queue$path <- file.path(clips_dir, queue$species_folder, queue$clip_file)
  if (isTRUE(blind)) queue <- queue[blind_order(nrow(queue), reviewer), ]
  n_missing <- sum(!file.exists(queue$path))
  if (n_missing == nrow(queue)) {
    stop("None of the clips was found in `clips_dir` (",
         clips_dir, "/<species_folder>/<clip_file>).", call. = FALSE)
  }
  if (n_missing > 0) {
    warning(n_missing, " clip(s) not found in `clips_dir`; they are shown ",
            "without audio.", call. = FALSE)
  }
  queue
}

#' Order of the blind review
#'
#' Shuffled once per reviewer, always the same for the same reviewer (a
#' resumed session shows the same order), and unlike the manifest, which is
#' sorted by score.
#'
#' @param n Integer scalar, number of clips.
#' @param reviewer Character scalar or `NULL`, the reviewer.
#' @return Integer vector, a permutation of `seq_len(n)`.
#' @noRd
blind_order <- function(n, reviewer = NULL) {
  seed <- sum(utf8ToInt(paste0("sheepdog",
                                   if (is.null(reviewer)) "" else reviewer)))
  withr::with_seed(seed, sample.int(n))
}

#' Required columns of the verdicts file
#' @noRd
verdict_columns <- c("clip_file", "species_folder", "reviewer", "verdict",
                     "time")
#' Optional identity columns of the verdicts file (since 3.4.0)
#'
#' What a negative or uncertain clip is, and the certainty of the reviewer.
#' @noRd
identity_columns <- c("identity", "identity_certainty")
#' Allowed values of `identity_certainty`
#' @noRd
identity_certainties <- c("sure", "probable")

#' Categories offered for the identity of a negative clip
#'
#' The fixed categories that [run_app()] suggests, besides the classes of
#' the manifest, for what a negative or uncertain clip is.
#'
#' @return A character vector.
#' @seealso [run_app()], [join_identities()], [confuser_summary()].
#' @examples
#' identity_categories()
#' @export
identity_categories <- function() {
  c("bird", "insect", "rain", "other_anuran", "noise", "unknown")
}

#' Append a verdict to the verdicts file
#'
#' Creates the file with a header when it does not exist; an older file is
#' first upgraded with `upgrade_verdict_log()`.
#'
#' @param file Character scalar, path to the verdicts CSV.
#' @param clip_file,species_folder Character scalars identifying the clip.
#' @param reviewer Character scalar or `NULL`.
#' @param verdict Character scalar: `"positive"`, `"negative"` or
#'   `"uncertain"`.
#' @param identity Character vector or `NULL`, identity of a negative or
#'   uncertain clip; ignored for positives.
#' @param identity_certainty Character scalar or `NULL`, one of
#'   `identity_certainties`.
#' @return The one-row tibble written, invisibly.
#' @noRd
append_verdict <- function(file, clip_file, species_folder, reviewer,
                           verdict, identity = NULL,
                           identity_certainty = NULL) {
  id <- clean_identity(identity)
  certainty <- if (is.na(id) || is.null(identity_certainty)) NA_character_
             else match.arg(identity_certainty, identity_certainties)
  if (verdict == "positive") {
    id <- NA_character_
    certainty <- NA_character_
  }
  row <- tibble(clip_file = clip_file, species_folder = species_folder,
                reviewer = if (is.null(reviewer)) NA_character_ else
                  reviewer,
                verdict = verdict,
                time = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
                identity = id, identity_certainty = certainty)
  is_new <- !file.exists(file)
  if (is_new) {
    dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  } else {
    upgrade_verdict_log(file)
  }
  write_csv(row, file, append = !is_new, col_names = is_new, na = "")
  invisible(row)
}

#' Upgrade a verdicts file of an earlier version
#'
#' A file without the identity columns is rewritten once with them empty,
#' so that new lines fit the header.
#'
#' @param file Character scalar, path to the verdicts CSV.
#' @return Logical scalar, invisibly: `TRUE` when the file was rewritten.
#' @noRd
upgrade_verdict_log <- function(file) {
  header <- names(read_csv(file, n_max = 0, show_col_types = FALSE))
  if (all(identity_columns %in% header)) return(invisible(FALSE))
  log <- read_csv(file, na = "", show_col_types = FALSE,
                  col_types = readr::cols(.default = readr::col_character()))
  for (col in setdiff(identity_columns, names(log))) {
    log[[col]] <- NA_character_
  }
  write_csv(log[c(verdict_columns, identity_columns,
                  setdiff(names(log), c(verdict_columns, identity_columns)))],
            file, na = "")
  invisible(TRUE)
}

#' Clean the identity typed or chosen in the app
#'
#' @param identity Character vector or `NULL`.
#' @return Character scalar: several values joined as `"a|b"`, `NA` when
#'   empty.
#' @noRd
clean_identity <- function(identity) {
  if (is.null(identity)) return(NA_character_)
  id <- trimws(as.character(identity))
  id <- unique(id[!is.na(id) & nzchar(id)])
  if (length(id) == 0) NA_character_ else paste(id, collapse = "|")
}

#' Read the verdicts file
#'
#' @param file Character scalar, path to the verdicts CSV.
#' @param last_only Logical scalar; if `TRUE`, only the last verdict of each
#'   clip and reviewer, else every line in click order.
#' @return A tibble of character columns `verdict_columns` and
#'   `identity_columns`; empty when the file does not exist.
#' @noRd
read_verdict_log <- function(file, last_only = TRUE) {
  empty <- tibble(clip_file = character(), species_folder = character(),
                  reviewer = character(), verdict = character(),
                  time = character(), identity = character(),
                  identity_certainty = character())
  if (!file.exists(file)) return(empty)
  # 0 bytes: with no header, new verdicts would be written without one
  if (file.size(file) == 0) {
    stop("`verdicts_file` is empty (0 bytes): ", file, ". Delete it to ",
         "start a new log, or restore the copy with the verdicts.",
         call. = FALSE)
  }
  log <- read_csv(file, na = "", show_col_types = FALSE,
                  col_types = readr::cols(.default = readr::col_character()))
  check_columns(log, verdict_columns, "verdicts_file")
  invalid <- setdiff(log$verdict, c("positive", "negative", "uncertain"))
  if (length(invalid) > 0) {
    stop("Unknown verdict(s) in `verdicts_file`: ",
         paste(invalid, collapse = ", "), call. = FALSE)
  }
  for (col in setdiff(identity_columns, names(log))) {
    log[[col]] <- NA_character_
  }
  if (!last_only) return(log)
  last_verdicts(log)
}

#' Keep the last verdict of each clip and reviewer
#'
#' The row order is the click order, so the last row counts.
#'
#' @param log A data frame of verdicts with columns `clip_file`,
#'   `species_folder` and `reviewer`.
#' @return `log` with one row per clip x reviewer, in click order.
#' @noRd
last_verdicts <- function(log) {
  log$.order <- seq_len(nrow(log))
  log |>
    arrange(desc(.order)) |>
    distinct(clip_file, species_folder, reviewer, .keep_all = TRUE) |>
    arrange(.order) |>
    select(-.order)
}

#' Spectrogram palettes: label -> palette of grDevices::hcl.colors()
#' @noRd
spectrogram_palettes <- c("Gray" = "Grays", "Viridis" = "Viridis",
                          "Inferno" = "Inferno", "Mako" = "Mako",
                          "Heat" = "Heat")
#' FFT window sizes offered in the app
#' @noRd
spectrogram_fft <- c(256L, 512L, 1024L, 2048L)

#' Plot the spectrogram of a clip
#'
#' Uses 'av', with small margins to fit the app. 'av' returns smaller
#' values where the sound is louder: in grey, loud sound is black on white;
#' in the colour palettes, it is light on dark.
#'
#' @param path Character scalar, path to the audio clip.
#' @param max_freq Numeric scalar or `NULL`, top of the plot in kHz.
#' @param fft Integer scalar, size of the Hann window.
#' @param overlap Numeric scalar in \[0, 1), window overlap.
#' @param palette Character scalar, a name of `spectrogram_palettes`.
#' @param brightness Numeric scalar, shift of the scale (0 = none).
#' @param contrast Numeric scalar, stretch of the scale around its middle
#'   (1 = none).
#' @return A list with the plot region (`plt`) and axis limits (`usr`),
#'   invisibly, for the playhead line.
#' @noRd
plot_spectrogram <- function(path, max_freq = NULL, fft = 1024L,
                             overlap = 0.9, palette = "Gray",
                             brightness = 0, contrast = 1) {
  x <- av::read_audio_fft(path, window = av::hanning(fft),
                          overlap = overlap)
  freq <- attr(x, "frequency") / 1000
  keep <- if (is.null(max_freq)) TRUE else freq <= max_freq
  z <- t(x[keep, , drop = FALSE])
  # scale from 0 (loudest) to 1 (silence): the quietest half of the pixels
  # is the background. Contrast stretches the scale around the middle;
  # brightness lightens the image (towards white in grey; towards the light
  # end, that of loud sound, in the colour palettes).
  ceil <- stats::quantile(z, 0.5, names = FALSE)
  floor_val <- min(z)
  v <- if (ceil > floor_val) {
    (pmin(z, ceil) - floor_val) / (ceil - floor_val)
  } else {
    z * 0
  }
  v <- (v - 0.5) * contrast + 0.5
  v <- v + if (identical(palette, "Gray")) brightness else -brightness
  v <- pmin(pmax(v, 0), 1)
  op <- graphics::par(mar = c(4, 4, 0.5, 0.5))
  on.exit(graphics::par(op), add = TRUE)
  # the top of the axis is the requested one, not the last FFT bin
  top <- if (is.null(max_freq)) max(freq) else min(max_freq, max(freq))
  graphics::image(attr(x, "time"), freq[keep], v, zlim = c(0, 1),
                  ylim = c(0, top), col = spectrogram_colours(palette),
                  xlab = "Time (s)", ylab = "Frequency (kHz)",
                  useRaster = TRUE)
  # plot region and axes, for the line that follows the audio
  invisible(list(plt = graphics::par("plt"), usr = graphics::par("usr")))
}

#' JavaScript of the dashed line that follows the audio on the spectrogram
#'
#' The server sends the plot region (fractions of the image) and the time
#' range.
#' @noRd
playhead_js <- "
$(function() {
  var cfg = {};
  Shiny.addCustomMessageHandler('sheepdog-playhead', function(m) {
    cfg[m.line] = m;
  });
  function step() {
    for (var id in cfg) {
      var m = cfg[id], line = document.getElementById(id);
      if (!line) continue;
      var img = line.parentElement.querySelector('img');
      var au = document.querySelector('#' + m.player + ' audio');
      if (!img || !au || !img.clientWidth) { line.style.display = 'none'; continue; }
      var f = (au.currentTime - m.t0) / (m.t1 - m.t0);
      f = Math.max(0, Math.min(1, f));
      var W = img.clientWidth, H = img.clientHeight;
      line.style.left = (img.offsetLeft + W * (m.plt[0] + f * (m.plt[1] - m.plt[0]))) + 'px';
      line.style.top = (img.offsetTop + H * (1 - m.plt[3])) + 'px';
      line.style.height = (H * (m.plt[3] - m.plt[2])) + 'px';
      line.style.borderLeftColor = m.colour || '#d62728';
      line.style.display = 'block';
    }
    window.requestAnimationFrame(step);
  }
  window.requestAnimationFrame(step);
});"

#' Colours of a spectrogram palette
#'
#' @param palette Character scalar, a name of `spectrogram_palettes`;
#'   unknown names give grey.
#' @return Character vector of 64 colours.
#' @noRd
spectrogram_colours <- function(palette = "Gray") {
  if (identical(palette, "Gray") || !palette %in% names(spectrogram_palettes)) {
    return(grDevices::gray.colors(64, start = 0, end = 1))
  }
  # loud sound (low values) gets the light end of the palette
  grDevices::hcl.colors(64, spectrogram_palettes[[palette]], rev = TRUE)
}

#' Keys of the Review tab and their verdicts
#' @noRd
review_keys <- c(p = "positive", n = "negative", u = "uncertain")

#' UI of the app from its state
#'
#' Only the review, or the Intro, Sampling, Review and Export tabs (Sampling
#' and Export ask for the folders when they are missing).
#'
#' @param st Environment from `app_state()`.
#' @return A 'shiny' page.
#' @noRd
app_ui <- function(st) {
  title <- paste0("sheepdog", if (!is.null(st$reviewer))
    paste0(" (", st$reviewer, ")"))
  if (st$review_only) {
    return(shiny::fluidPage(title = "sheepdog review",
                            shiny::titlePanel(paste0(title,
                                                     ": clip review")),
                            review_ui("review", st$max_freq)))
  }
  ready <- app_ready(st)
  shiny::navbarPage(
    title, id = "tabs", selected = if (is.null(st$clip_queue)) "Intro" else
      "Review",
    shiny::tabPanel("Intro", intro_ui(st)),
    shiny::tabPanel("Sampling", if (ready) {
      sampling_ui("sampling", st$detections, st$audio_dir)
    } else needs_folders_ui()),
    shiny::tabPanel("Review", review_ui("review", st$max_freq)),
    shiny::tabPanel("Export", if (ready) {
      export_ui("export", st$output_dir)
    } else needs_folders_ui()))
}

#' Build the app: UI and server
#'
#' Without `detections`, only the Review tab works.
#'
#' @param st Environment from `app_state()`, after `load_app_state()`.
#' @return A 'shiny' app object.
#' @noRd
review_app <- function(st) {
  resource <- "sheepdog_clips"
  shiny::addResourcePath("sheepdog_app",
                         system.file("app", package = "sheepdog"))
  register_clips <- function() {
    if (is.null(st$clips_dir)) return(invisible())
    dir.create(st$clips_dir, recursive = TRUE, showWarnings = FALSE)
    shiny::addResourcePath(resource, normalizePath(st$clips_dir))
  }
  register_clips()
  # the UI is rebuilt from the state at each page load
  ui <- function(req) app_ui(st)
  server <- function(input, output, session) {
    queue_r <- shiny::reactiveVal(st$clip_queue)
    if (!st$review_only) {
      setup_server("setup", st, session, register_clips)
      confirm_folders(st, input, session)
    }
    if (!st$review_only && app_ready(st)) {
      output_dir <- st$output_dir
      cuts <- sampling_server("sampling", st$detections, st$selection_dir,
                              output_dir, st$recordings, st$classifier,
                              audio_listed = st$audio_dir)
      # newly cut clips go to the review queue
      shiny::observeEvent(cuts(), {
        q <- tryCatch(
          review_queue(file.path(output_dir, "clip_manifest.csv"),
                       st$clips_dir, st$reviewer, blind = st$blind),
          error = function(e) {
            shiny::showNotification(conditionMessage(e), type = "warning",
                                    duration = NULL)
            NULL
          })
        queue_r(q)
        st$clip_queue <- q
        if (!is.null(q)) shiny::updateNavbarPage(session, "tabs", "Review")
      }, ignoreInit = TRUE)
      export_server("export", st$detections, output_dir, st$clips_dir,
                    st$verdicts_file, st$recordings, st$classifier)
    }
    review_server("review", queue_r, st$verdicts_file, st$reviewer,
                  resource, st$max_freq, blind = st$blind)
  }
  shiny::shinyApp(ui = ui, server = server)
}

#' UI of the Review tab
#'
#' @param id Character scalar, module id.
#' @param max_freq Numeric scalar or `NULL`, initial top of the
#'   spectrogram in kHz.
#' @return A 'shiny' tag list.
#' @noRd
review_ui <- function(id, max_freq = 12) {
  ns <- shiny::NS(id)
  keys_js <- sprintf(
    "document.addEventListener('keydown', function(e) {
       if (['INPUT', 'SELECT', 'TEXTAREA'].includes(e.target.tagName)) return;
       if (e.key === ' ') {
         var au = document.querySelector('#%s audio');
         if (au) { e.preventDefault(); if (au.paused) au.play(); else au.pause(); }
         return;
       }
       Shiny.setInputValue('%s', e.key, {priority: 'event'});
     });", ns("player"), ns("key"))
  shiny::tagList(
    shiny::tags$head(shiny::tags$script(shiny::HTML(keys_js)),
                     shiny::tags$script(shiny::HTML(playhead_js)),
                     shiny::tags$style(shiny::HTML(
                       paste("td { white-space: nowrap; }",
                             "td + td { white-space: normal;",
                             "word-break: break-all; }")))),
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        width = 3,
        shiny::selectInput(ns("species"), "Species", c("All" = "")),
        hint("Show only the clips of this species."),
        shiny::checkboxInput(ns("pending"), "Only clips not yet reviewed",
                             value = TRUE),
        hint("Hide the clips that already have a verdict."),
        shiny::textOutput(ns("progress")),
        shiny::hr(),
        shiny::tableOutput(ns("info")),
        shiny::helpText("Keys: p positive, n negative, u uncertain,",
                        "right arrow next, left arrow previous, space play or pause.")
      ),
      shiny::mainPanel(
        width = 9,
        shiny::h4(shiny::textOutput(ns("position"), inline = TRUE),
                  style = "margin-top: 0;"),
        shiny::fluidRow(
          shiny::column(2, shiny::selectInput(
            ns("palette"), "Palette", names(spectrogram_palettes))),
          shiny::column(2, shiny::selectInput(
            ns("fft"), "FFT window", spectrogram_fft, selected = 1024L)),
          shiny::column(2, shiny::numericInput(
            ns("max_freq"), "Max. kHz",
            if (is.null(max_freq)) NA else max_freq, min = 0.5, step = 0.5)),
          shiny::column(3, shiny::sliderInput(
            ns("brightness"), "Brightness", min = -50, max = 50, value = 0,
            step = 5, post = "%", ticks = FALSE)),
          shiny::column(3, shiny::sliderInput(
            ns("contrast"), "Contrast", min = 25, max = 300, value = 100,
            step = 25, post = "%", ticks = FALSE))),
        shiny::fluidRow(shiny::column(12, hint(
          "FFT window in samples, with 90% overlap: larger windows sharpen",
          "the frequency and blur the time. Max. kHz is the top of the",
          "plot; empty shows the whole band."))),
        shiny::div(
          style = "position: relative;",
          shiny::plotOutput(ns("spectrogram"), height = "320px"),
          shiny::div(id = ns("playhead"), style = paste(
            "position: absolute; display: none; width: 0;",
            "border-left: 1px dashed #d62728; pointer-events: none;"))),
        shiny::uiOutput(ns("player")),
        shiny::br(),
        shiny::actionButton(ns("positive"), "Positive (p)",
                            class = "btn-success"),
        shiny::actionButton(ns("negative"), "Negative (n)",
                            class = "btn-danger"),
        shiny::actionButton(ns("uncertain"), "Uncertain (u)",
                            class = "btn-warning"),
        shiny::actionButton(ns("previous"), "< Previous"),
        shiny::actionButton(ns("next_clip"), "Next >"),
        shiny::br(), shiny::br(),
        shiny::fluidRow(
          shiny::column(8, shiny::selectizeInput(
            ns("identity"), "Identity of a negative or uncertain clip",
            choices = NULL, multiple = TRUE,
            options = list(create = TRUE, persist = FALSE,
                           placeholder = "Optional: species or category"))),
          shiny::column(4, shiny::radioButtons(
            ns("identity_certainty"), "Certainty", identity_certainties,
            inline = TRUE))),
        shiny::fluidRow(shiny::column(12, hint(
          "Type or choose what the sound is, then click Negative or",
          "Uncertain. Two or more choices mean either of them."))),
        shiny::textOutput(ns("current_verdict"))
      )
    )
  )
}

#' Server of the Review tab
#'
#' @param id Character scalar, module id.
#' @param clip_queue The review queue: a data frame from `review_queue()`, or a
#'   reactive returning it (`NULL` before the clips are cut).
#' @param verdicts_file Character scalar, path to the verdicts CSV.
#' @param reviewer Character scalar or `NULL`, the reviewer.
#' @param resource Character scalar, 'shiny' resource path of the clips.
#' @param max_freq Numeric scalar or `NULL`, default top of the
#'   spectrogram in kHz.
#' @param blind Logical scalar; if `TRUE`, hides clip name, score and
#'   design.
#' @return A list of reactives: `current` (index of the current clip),
#'   `verdicts` (named verdicts of the reviewer) and `queue`.
#' @noRd
review_server <- function(id, clip_queue, verdicts_file, reviewer, resource = "",
                          max_freq = NULL, blind = FALSE) {
  shiny::moduleServer(id, function(input, output, session) {
    queue_r <- if (shiny::is.reactive(clip_queue)) clip_queue else shiny::reactive(clip_queue)
    tab <- shiny::reactive({
      f <- queue_r()
      if (is.null(f)) f <- tibble(clip_file = character(),
                                  species_folder = character())
      f
    })
    key <- shiny::reactive(paste(tab()$species_folder, tab()$clip_file,
                                 sep = "/"))
    read_logged <- function() {
      log <- read_verdict_log(verdicts_file)
      rev <- if (is.null(reviewer)) NA_character_ else reviewer
      log <- log[log$reviewer %in% rev, ]
      stats::setNames(log$verdict,
                      paste(log$species_folder, log$clip_file, sep = "/"))
    }
    verdicts <- shiny::reactiveVal(read_logged())
    current_idx <- shiny::reactiveVal(NA_integer_)
    suggestions <- shiny::reactive({
      f <- tab()
      classes <- if ("species_code" %in% names(f)) f$species_code else NULL
      unique(c(sort(unique(stats::na.omit(as.character(classes)))),
               identity_categories()))
    })
    clear_identity <- function() {
      shiny::updateSelectizeInput(session, "identity",
                                  choices = suggestions(),
                                  selected = character(), server = FALSE)
      shiny::updateRadioButtons(session, "identity_certainty",
                                selected = "sure")
    }
    shiny::observeEvent(tab(), {
      shiny::updateSelectInput(session, "species", choices = c(
        "All" = "", sort(unique(tab()$species_folder))))
      clear_identity()
    })

    # clips visible with the filters; the current clip stays visible until
    # the reviewer leaves it
    visible <- shiny::reactive({
      f <- tab()
      ok <- rep(TRUE, nrow(f))
      if (!is.null(input$species) && nzchar(input$species)) {
        ok <- ok & f$species_folder == input$species
      }
      if (isTRUE(input$pending)) {
        ok <- ok & !key() %in% names(shiny::isolate(verdicts()))
      }
      which(ok)
    })
    shiny::observeEvent(list(tab(), input$species, input$pending), {
      v <- visible()
      current_idx(if (length(v) > 0) v[1] else NA_integer_)
    })

    move <- function(step) {
      v <- visible()
      i <- current_idx()
      if (is.na(i)) {
        current_idx(if (length(v) > 0) v[1] else NA_integer_)
        return(invisible())
      }
      after <- if (step > 0) v[v > i] else rev(v[v < i])
      if (length(after) > 0) current_idx(after[1])
    }
    mark <- function(verdict) {
      i <- current_idx()
      if (is.na(i)) return(invisible())
      f <- tab()
      append_verdict(verdicts_file, f$clip_file[i], f$species_folder[i],
                     reviewer, verdict, identity = input$identity,
                     identity_certainty = if (is.null(
                       input$identity_certainty)) "sure" else
                       input$identity_certainty)
      if (length(input$identity) > 0) clear_identity()
      vv <- verdicts()
      vv[key()[i]] <- verdict
      verdicts(vv)
      move(1)
    }
    shiny::observeEvent(input$positive, mark("positive"))
    shiny::observeEvent(input$negative, mark("negative"))
    shiny::observeEvent(input$uncertain, mark("uncertain"))
    shiny::observeEvent(input$next_clip, move(1))
    shiny::observeEvent(input$previous, move(-1))
    shiny::observeEvent(input$key, {
      k <- tolower(input$key)
      if (k %in% names(review_keys)) {
        mark(review_keys[[k]])
      } else if (k == "arrowright") {
        move(1)
      } else if (k == "arrowleft") {
        move(-1)
      }
    })

    output$position <- shiny::renderText({
      i <- current_idx()
      n_done <- sum(key() %in% names(verdicts()))
      n <- nrow(tab())
      if (is.na(i)) return(paste0(n_done, " of ", n, " clips reviewed"))
      paste0("Clip ", i, " of ", n, "  |  ", n_done, " of ", n,
             " clips reviewed")
    })
    output$progress <- shiny::renderText({
      n_done <- sum(key() %in% names(verdicts()))
      paste0(n_done, " of ", nrow(tab()), " clips reviewed")
    })
    output$info <- shiny::renderTable({
      i <- current_idx()
      shiny::req(!is.na(i))
      f <- tab()
      info <- tibble(field = c("Clip", "Species", "Site", "Night", "Hour",
                               "Score", "Design"),
                     value = c(f$clip_file[i], f$species_folder[i],
                               as.character(f$site[i]),
                               as.character(f$night[i]),
                               as.character(f$recording_hour[i]),
                               format(f$confidence[i], digits = 3),
                               as.character(f$sampling_mode[i])))
      # blind review: the clip name starts with the score
      if (isTRUE(blind)) info <- info[!info$field %in% c("Clip", "Score",
                                                          "Design"), ]
      info
    }, colnames = FALSE)
    output$current_verdict <- shiny::renderText({
      if (is.null(queue_r())) {
        return("No clips yet: draw and cut them in the Sampling tab.")
      }
      i <- current_idx()
      if (is.na(i)) return("No clip left with these filters.")
      v <- verdicts()[key()[i]]
      if (is.na(v)) "Not reviewed yet." else paste("Current verdict:", v)
    })
    output$spectrogram <- shiny::renderPlot({
      i <- current_idx()
      shiny::req(!is.na(i), file.exists(tab()$path[i]))
      top_freq <- if (is.null(input$max_freq)) max_freq else input$max_freq
      if (is.null(top_freq) || is.na(top_freq) || top_freq <= 0) {
        top_freq <- NULL
      }
      fft <- suppressWarnings(as.integer(input$fft))
      if (length(fft) == 0 || is.na(fft)) fft <- 1024L
      pct <- function(x, default) if (is.null(x) || is.na(x)) default else
        x / 100
      g <- plot_spectrogram(tab()$path[i], top_freq, fft = fft,
                            overlap = 0.9,
                            palette = if (is.null(input$palette)) "Gray" else
                              input$palette,
                            brightness = pct(input$brightness, 0),
                            contrast = pct(input$contrast, 1))
      session$sendCustomMessage("sheepdog-playhead", list(
        line = session$ns("playhead"), player = session$ns("player"),
        plt = g$plt, t0 = g$usr[1], t1 = g$usr[2],
        colour = if (identical(input$palette, "Gray") ||
                     is.null(input$palette)) "#d62728" else "#ffffff"))
    })
    output$player <- shiny::renderUI({
      i <- current_idx()
      shiny::req(!is.na(i), file.exists(tab()$path[i]))
      f <- tab()
      src <- paste(resource, utils::URLencode(f$species_folder[i],
                                             reserved = TRUE),
                   utils::URLencode(f$clip_file[i], reserved = TRUE),
                   sep = "/")
      shiny::tags$audio(src = src, type = "audio/wav", controls = NA,
                        autoplay = NA, style = "width: 100%;")
    })
    invisible(list(current = current_idx, verdicts = verdicts, queue = tab))
  })
}

#' UI of the Intro tab
#'
#' The figure that summarises the sampling modes, and the Audio panel.
#'
#' @param st Environment from `app_state()`.
#' @return A 'shiny' navlist panel.
#' @noRd
intro_ui <- function(st) {
  shiny::navlistPanel(
    id = "intro_nav", widths = c(2, 10), well = FALSE,
    shiny::tabPanel(
      "Graphical abstract",
      shiny::h3("How sheepdog picks the clips you review"),
      shiny::p("Each panel shows one night of 30-minute recordings",
               "(simulated scores) and which clips each sampling mode and",
               "occasion would give. Choose the design in the Sampling tab,",
               "review the clips in the Review tab and write the occupancy",
               "tables in the Export tab."),
      shiny::tags$img(src = "sheepdog_app/intro.png",
                      alt = "Sampling modes, occasions and strata of sheepdog",
                      style = "max-width: 100%; height: auto;")),
    shiny::tabPanel("Audio panel", setup_ui("setup", st)))
}

#' Short grey text under the label of a field
#'
#' @param ... Character pieces, pasted with spaces; may hold HTML.
#' @return A 'shiny' `div` tag.
#' @noRd
hint <- function(...) {
  shiny::tags$div(shiny::HTML(paste(...)), style = paste(
    "margin-top: -10px; margin-bottom: 12px;",
    "font-size: 0.85em; color: #6c757d;"))
}

#' Label of the threshold field
#'
#' The threshold is required only in `"random_detections"`.
#'
#' @param mode Character scalar, the sampling mode.
#' @return Character scalar.
#' @noRd
threshold_label <- function(mode) {
  paste0("Threshold of the occupancy analysis (",
         if (identical(mode, "random_detections")) "required" else "optional",
         ")")
}

#' Strata presets of select_clips()
#' @noRd
strata_presets <- c("night_hour", "night", "hour", "week", "month",
                    "site_species")

#' UI of the Sampling tab
#'
#' @param id Character scalar, module id.
#' @param detections A data frame of BirdNET predictions (columns `site`
#'   and `species_code`), for the site and species choices.
#' @param audio_dir Character scalar or `NULL`, initial audio folder.
#' @return A 'shiny' sidebar layout.
#' @noRd
sampling_ui <- function(id, detections, audio_dir = NULL) {
  ns <- shiny::NS(id)
  sites <- sort(unique(as.character(detections$site)))
  species <- sort(unique(str_extract(detections$species_code, "[^_]+$")))
  num <- function(name, label, value = NA, ...) {
    shiny::numericInput(ns(name), label, value, ...)
  }
  shiny::sidebarLayout(
    shiny::sidebarPanel(
      width = 4,
      shiny::selectInput(ns("mode"), "Sampling mode",
                         c("random_detections", "top", "random_recordings",
                           "score_bands")),
      hint("<b>top</b>: only the highest-scored clips (n_top per night x",
           "hour), for retraining and calibration.",
           "<b>random_detections</b>: draw clips from occasions drawn at",
           "random among those with detections above the threshold; every",
           "detection above the threshold in a drawn occasion is a clip.",
           "<b>random_recordings</b>: draw recordings (or minutes) at",
           "random from everything recorded, with or without detections,",
           "to annotate by ear.",
           "<b>score_bands</b>: draw n_top clips per stratum x score band,",
           "across the whole score range, for thresholds and calibration;",
           "not for the false-positive rate of an occupancy model."),
      shiny::selectInput(ns("occasion_unit"), "Occasion", c("file", "minute")),
      hint("The unit of time over which a species counts as detected or",
           "not at a site: a whole file or one minute of it."),
      num("threshold", threshold_label("random_detections"),
          min = 0, max = 1, step = 0.05),
      hint("Score from which a prediction counts as a detection. Needed by",
           "random_detections; use the value of the occupancy analysis."),
      num("n_top", "n_top (per stratum, or per night x hour in top)", 2,
          min = 1),
      hint("<b>top</b>: clips kept per site x species x night x hour.",
           "<b>random_detections</b>: occasions drawn per stratum.",
           "<b>score_bands</b>: clips drawn per stratum x score band."),
      shiny::conditionalPanel(
        "input.mode == 'random_detections' || input.mode == 'score_bands'",
        ns = ns,
        shiny::selectInput(ns("strata"), "Strata", strata_presets),
        hint("Groups, within each site x species, in which the occasions",
             "(or, in score_bands, the clips) are drawn (e.g. night x",
             "hour).")),
      shiny::conditionalPanel(
        "input.mode == 'score_bands'", ns = ns,
        shiny::textInput(ns("score_breaks"), "Score bands (limits)",
                         "0.1, 0.4, 0.7, 1"),
        hint("Increasing limits between 0 and 1, separated by commas.",
             "Predictions outside them are not drawn.")),
      shiny::conditionalPanel(
        "input.mode == 'random_recordings'", ns = ns,
        num("recording_fraction", "Fraction of recordings per site", 0.01,
            min = 0, max = 1),
        hint("Share of the recordings (or minutes) of each site drawn, at",
             "least one per site.")),
      num("target_total", "Total clips per site (optional)", min = 1),
      hint("Split evenly among species. Not used by random_recordings",
           "or score_bands."),
      num("max_per_species", "Maximum clips per site x species (optional)",
          min = 1),
      hint("A fixed limit per site and species. Ignored when a total per",
           "site is set."),
      num("min_confidence", "Minimum score", 0.1, min = 0, max = 1,
          step = 0.05),
      hint("top only: predictions below this score are skipped. The",
           "random modes use the threshold."),
      shiny::selectizeInput(ns("sites"), "Sites (all if empty)", sites,
                            multiple = TRUE),
      hint("Draw only from these sites."),
      shiny::selectizeInput(ns("species"), "Species (all if empty)",
                            species, multiple = TRUE),
      hint("Draw only these species (short codes, e.g. boa-ran)."),
      shiny::fluidRow(
        shiny::column(6, num("hour_start", "From hour", min = 0, max = 23)),
        shiny::column(6, num("hour_end", "To hour", min = 0, max = 23))),
      hint("Hours of the day (0-23) to draw from. The window can cross",
           "midnight, e.g. 17 to 2."),
      num("seed", "Seed", 2026),
      hint("Fixes the random draw, so the same seed gives the same clips."),
      shiny::textInput(ns("remap_from"), "Remap audio paths from (optional)"),
      shiny::textInput(ns("remap_to"), "to"),
      hint("If the recordings moved since BirdNET ran, replace the start of",
           "their paths, e.g. N:/ by /Volumes/Arara/."),
      shiny::textInput(ns("audio_dir"), "Audio folder (optional)",
                       if (is.null(audio_dir)) "" else audio_dir),
      hint("Folder of the recordings (subfolders included). The app checks",
           "the audio paths after each draw; when some are missing, it",
           "looks for the files here by name and offers to use them."),
      shiny::actionButton(ns("draw"), "Draw", class = "btn-primary"),
      shiny::hr(),
      shiny::checkboxInput(ns("simulate"),
                           "Simulate (check the audio, cut nothing)"),
      hint("Shows what would be cut, without writing any audio."),
      shiny::checkboxInput(ns("replace"),
                           "Replace an existing clip_manifest.csv"),
      hint("Overwrites the manifest of an earlier cut in this round."),
      shiny::actionButton(ns("cut"), "Cut clips")
    ),
    shiny::mainPanel(
      width = 8,
      shiny::uiOutput(ns("notes")),
      shiny::uiOutput(ns("counts_title")),
      shiny::tableOutput(ns("counts")),
      shiny::uiOutput(ns("inclusion_title")),
      shiny::tableOutput(ns("inclusion")),
      shiny::uiOutput(ns("cut_title")),
      shiny::tableOutput(ns("cut_status"))
    )
  )
}

#' Arguments of select_clips() from the Sampling form
#'
#' Empty fields are dropped, so they keep the default of the function.
#'
#' @param input The 'shiny' input of the Sampling tab, or a list with the
#'   same elements.
#' @return A named list of arguments.
#' @noRd
sampling_args <- function(input) {
  is_empty <- function(x) is.null(x) || length(x) == 0 || all(is.na(x)) ||
    identical(x, "")
  args <- list(sampling_mode = input$mode,
               occasion_unit = input$occasion_unit,
               threshold = input$threshold, n_top = input$n_top,
               min_confidence = input$min_confidence, seed = input$seed,
               target_total = input$target_total,
               max_per_species = input$max_per_species,
               sites = input$sites, species = input$species,
               hour_start = input$hour_start, hour_end = input$hour_end,
               remap_from = input$remap_from, remap_to = input$remap_to)
  if (input$mode %in% c("random_detections", "score_bands")) {
    args$strata <- input$strata
  }
  if (identical(input$mode, "score_bands")) {
    args$score_breaks <- parse_breaks(input$score_breaks)
    args$target_total <- NULL
    args$max_per_species <- NULL
    args$threshold <- NULL
  }
  if (identical(input$mode, "random_recordings")) {
    args$recording_fraction <- input$recording_fraction
  }
  args[!vapply(args, is_empty, logical(1))]
}

#' Parse the score band limits typed in the app
#'
#' Accepts `"0.1, 0.4, 0.7, 1"`; a decimal comma also works when the values
#' are separated by semicolons (`"0,1; 0,4"`).
#'
#' @param x Character scalar or `NULL`.
#' @return Numeric vector, or `NULL` when `x` is empty.
#' @noRd
parse_breaks <- function(x) {
  if (is.null(x) || !nzchar(trimws(x))) return(NULL)
  parts <- if (grepl(";", x)) strsplit(x, ";")[[1]] else strsplit(x, ",")[[1]]
  parts <- gsub(",", ".", trimws(parts))
  values <- suppressWarnings(as.numeric(parts[nzchar(parts)]))
  if (anyNA(values)) {
    stop("Score bands must be numbers separated by commas, ",
         "such as 0.1, 0.4, 0.7, 1.", call. = FALSE)
  }
  values
}

#' Evaluate an expression keeping its warnings and messages
#'
#' @param expr Expression to evaluate.
#' @return A list with `value` (the result) and `notes` (character vector
#'   of the warnings and messages), to show in the app.
#' @noRd
with_notes <- function(expr) {
  acc <- new.env(parent = emptyenv())
  acc$notes <- character()
  value <- withCallingHandlers(
    expr,
    warning = function(w) {
      acc$notes <- c(acc$notes, conditionMessage(w))
      invokeRestart("muffleWarning")
    },
    message = function(m) {
      acc$notes <- c(acc$notes, trimws(conditionMessage(m)))
      invokeRestart("muffleMessage")
    })
  list(value = value, notes = acc$notes)
}

#' Check the recordings and look for the missing ones
#'
#' Missing recordings are looked for by file name in `audio_dir`
#' (subfolders included); names repeated in `audio_dir` are left out as
#' ambiguous.
#'
#' @param paths Character vector of audio paths.
#' @param audio_dir Character scalar or `NULL`, folder to search.
#' @param audio_pattern Character scalar, regular expression of the audio
#'   files.
#' @param files Character vector or `NULL`, the files of `audio_dir` when
#'   already listed (e.g. by the Audio panel tab), so that the folder is not
#'   scanned again at each draw.
#' @return A list with `n` (number of distinct paths), `missing` (missing
#'   paths), `found` (named character vector: found path, named by the
#'   missing one) and `remap` (the pair of folders when one pair explains
#'   every match, else `NULL`).
#' @noRd
locate_audio <- function(paths, audio_dir = NULL,
                         audio_pattern = "\\.(wav|flac|mp3)$",
                         files = NULL) {
  paths <- unique(paths[!is.na(paths) & nzchar(paths)])
  missing_paths <- paths[!file.exists(paths)]
  found <- character()
  remap <- NULL
  if (!is.null(audio_dir)) audio_dir <- sub("/+$", "", path.expand(audio_dir))
  if (length(missing_paths) > 0 && !is.null(audio_dir) && nzchar(audio_dir) &&
      dir.exists(audio_dir)) {
    audio_files <- if (!is.null(files)) files else
      list.files(audio_dir, audio_pattern, recursive = TRUE,
                 full.names = TRUE, ignore.case = TRUE)
    audio_files <- str_replace_all(audio_files, fixed("\\"), "/")
    file_names <- basename(audio_files)
    is_unique <- !(duplicated(file_names) |
                     duplicated(file_names, fromLast = TRUE))
    idx <- match(basename(missing_paths), file_names[is_unique])
    found <- stats::setNames(audio_files[is_unique][idx[!is.na(idx)]],
                             missing_paths[!is.na(idx)])
    if (length(found) > 0) {
      pairs <- unique(paste(dirname(names(found)), dirname(found),
                            sep = "\r"))
      if (length(pairs) == 1) {
        remap <- paste0(strsplit(pairs, "\r", fixed = TRUE)[[1]], "/")
      }
    }
  }
  list(n = length(paths), missing = missing_paths, found = found,
       remap = remap)
}

#' Reuse the files already listed for an audio folder
#'
#' The listed files serve `audio_dir` only when both folders are the same.
#'
#' @param audio_dir Character scalar or `NULL`, folder to search.
#' @param listed_dir Character scalar or `NULL`, folder already listed.
#' @param recordings A data frame with column `source_audio`, or `NULL`.
#' @return Character vector of paths, or `NULL`.
#' @noRd
listed_files <- function(audio_dir, listed_dir, recordings) {
  norm_dir <- function(d) {
    if (is.null(d) || !nzchar(d) || !dir.exists(path.expand(d))) {
      return(NA_character_)
    }
    normalizePath(path.expand(d), winslash = "/")
  }
  a <- norm_dir(audio_dir)
  if (is.null(recordings) || is.na(a) || !identical(a, norm_dir(listed_dir))) {
    return(NULL)
  }
  as.character(recordings$source_audio)
}

#' Note, after a draw, on the recordings found or missing
#'
#' @param chk A list from `locate_audio()`.
#' @param audio_dir Character scalar or `NULL`, the audio folder.
#' @return Character scalar, or an empty character vector when the found
#'   recordings are offered in a dialog.
#' @noRd
audio_note <- function(chk, audio_dir) {
  given <- !is.null(audio_dir) && nzchar(audio_dir)
  if (length(chk$missing) == 0) {
    return(paste0("All ", chk$n, " recordings of the draw were found."))
  }
  if (given && !dir.exists(path.expand(audio_dir))) {
    return(paste0("The audio folder ", audio_dir, " does not exist."))
  }
  if (length(chk$found) > 0) return(character())
  paste0(length(chk$missing), " of ", chk$n, " recordings of the draw ",
         "were not found (e.g. ", chk$missing[1], "). ",
         if (given) paste0("They are not in ", audio_dir, " either.")
         else paste("Give the folder of the recordings in \"Audio folder\"",
                    "or fill the remap fields, and draw again."))
}

#' Dialog asking whether to use the recordings found in the audio folder
#'
#' @param chk A list from `locate_audio()` with some `found`.
#' @param audio_dir Character scalar, the audio folder.
#' @param ns Namespace function of the module.
#' @return A 'shiny' modal dialog.
#' @noRd
relocate_dialog <- function(chk, audio_dir, ns) {
  from <- names(chk$found)[1]
  shiny::modalDialog(
    title = "Use the recordings of the audio folder?",
    shiny::p(length(chk$missing), " of ", chk$n, " recordings of the draw ",
             "are not where the selection tables say. ",
             length(chk$found), " of them were found in ", audio_dir, "."),
    shiny::p("For example:"),
    shiny::tags$ul(
      shiny::tags$li("selection tables: ", shiny::code(from)),
      shiny::tags$li("audio folder: ", shiny::code(chk$found[[1]]))),
    if (!is.null(chk$remap)) {
      shiny::p("That is, ", shiny::code(chk$remap[1]), " becomes ",
               shiny::code(chk$remap[2]), ".")
    },
    shiny::p("The manifest keeps the BirdNET path in ", shiny::code("begin_path"),
             " and uses the new one in ", shiny::code("source_audio"), "."),
    footer = shiny::tagList(
      shiny::modalButton("Keep the paths"),
      shiny::actionButton(ns("relocate"), "Use the audio folder",
                          class = "btn-primary")),
    easyClose = FALSE)
}

#' Server of the Sampling tab
#'
#' @param id Character scalar, module id.
#' @param detections A data frame of BirdNET predictions.
#' @param selection_dir Character scalar, folder of the selection tables.
#' @param output_dir Character scalar, folder of the round.
#' @param recordings A data frame of recordings, or `NULL`.
#' @param classifier Character scalar or `NULL`, label of the classifier.
#' @param audio_listed Character scalar or `NULL`, audio folder already
#'   listed in `recordings`.
#' @return A reactive integer that changes at each cut (the app then
#'   reloads the review queue).
#' @noRd
sampling_server <- function(id, detections, selection_dir, output_dir,
                            recordings = NULL, classifier = NULL,
                            audio_listed = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    selected <- shiny::reactiveVal(NULL)
    args_r <- shiny::reactiveVal(NULL)
    note_lines <- shiny::reactiveVal(character())
    status <- shiny::reactiveVal(NULL)
    shiny::observeEvent(input$mode, {
      shiny::updateNumericInput(session, "threshold",
                                label = threshold_label(input$mode))
    })
    n_cuts <- shiny::reactiveVal(0L)
    audio <- shiny::reactiveVal(NULL)       # result of locate_audio()
    relocated <- shiny::reactiveVal(NULL)  # recordings moved to a new folder

    shiny::observeEvent(input$draw, {
      args <- tryCatch(sampling_args(input), error = function(e) e)
      if (inherits(args, "error")) {
        note_lines(paste("Error:", conditionMessage(args)))
        return()
      }
      if (identical(input$mode, "random_recordings")) {
        args$recordings <- recordings
      }
      r <- tryCatch(with_notes(do.call(select_clips,
                                       c(list(detections), args))),
                    error = function(e) {
                      list(value = NULL, notes = paste("Error:",
                                                       conditionMessage(e)))
                    })
      if (identical(input$mode, "top")) {
        r$notes <- c(r$notes, paste(
          "\"top\" clips serve retraining and calibration; they hold fewer",
          "false positives than a random sample and do not estimate the",
          "false-positive rate."))
      }
      args$recordings <- NULL
      selected(r$value)
      args_r(args)
      status(NULL)
      relocated(NULL)
      audio(NULL)
      if (!is.null(r$value) && nrow(r$value) > 0) {
        chk <- locate_audio(r$value$source_audio, input$audio_dir,
                            files = listed_files(input$audio_dir,
                                                 audio_listed, recordings))
        audio(chk)
        r$notes <- c(r$notes, audio_note(chk, input$audio_dir))
        if (length(chk$found) > 0) {
          shiny::showModal(relocate_dialog(chk, input$audio_dir,
                                           session$ns))
        }
      }
      note_lines(r$notes)
    })

    shiny::observeEvent(input$relocate, {
      chk <- audio()
      sel <- selected()
      shiny::removeModal()
      if (is.null(chk) || is.null(sel)) return()
      idx <- match(sel$source_audio, names(chk$found))
      sel$source_audio[!is.na(idx)] <- unname(chk$found[idx[!is.na(idx)]])
      selected(sel)
      relocated(list(dir = input$audio_dir, n = length(chk$found),
                      remap = chk$remap))
      n_still_missing <- length(chk$missing) - length(chk$found)
      note_lines(c(
        paste0(length(chk$found), " recording(s) now read from ",
               input$audio_dir, "; the manifest will use these paths."),
        if (n_still_missing > 0) {
          paste0(n_still_missing, " recording(s) are still missing.")
        }))
    })

    shiny::observeEvent(input$cut, {
      sel <- selected()
      if (is.null(sel)) {
        note_lines("Draw the clips first.")
        return()
      }
      manifest_path <- file.path(output_dir, "clip_manifest.csv")
      if (file.exists(manifest_path) && !isTRUE(input$replace)) {
        note_lines(paste("clip_manifest.csv already exists in", output_dir,
                    "- tick \"Replace\" to write over it (the verdicts",
                    "already given refer to its clips)."))
        return()
      }
      simulate <- isTRUE(input$simulate)
      r <- with_notes(cut_clips(sel, output_dir, simulate = simulate))
      none_found <- all(r$value$status == "audio_not_found")
      if (!simulate) {
        write_csv(r$value, manifest_path)
        info <- extraction_info(selection_dir, classifier, simulate, args_r())
        re <- relocated()
        if (!is.null(re)) {
          info <- bind_rows(info, tibble(
            key = c("audio_dir", "recordings_relocated"),
            value = c(re$dir, as.character(re$n))))
        }
        write_csv(info, file.path(output_dir, "extraction_info.csv"))
        r$notes <- c(r$notes, paste("Manifest written to", manifest_path))
      }
      if (none_found) {
        r$notes <- c(r$notes, paste(
          "No recording was found, so no clip was cut. Give the folder of",
          "the recordings in \"Audio folder\" (or fill the remap fields),",
          "draw again and cut with \"Replace\" ticked."))
      }
      note_lines(r$notes)
      status(count(r$value, species_folder, status))
      if (!simulate && !none_found) n_cuts(n_cuts() + 1L)
    })

    output$notes <- shiny::renderUI({
      n <- note_lines()
      if (length(n) == 0) return(NULL)
      shiny::div(class = "alert alert-info",
                 lapply(n, function(x) shiny::p(x)))
    })
    # the titles only show with their table
    output$counts_title <- shiny::renderUI({
      shiny::req(selected(), nrow(selected()) > 0)
      shiny::h4("Clips per site and species")
    })
    output$inclusion_title <- shiny::renderUI({
      sel <- selected()
      shiny::req(sel, nrow(sel) > 0, any(!is.na(sel$inclusion_prob)))
      shiny::h4("Inclusion probability per species")
    })
    output$cut_title <- shiny::renderUI({
      shiny::req(status())
      shiny::h4("Cutting")
    })
    output$counts <- shiny::renderTable({
      sel <- selected()
      shiny::req(sel, nrow(sel) > 0)
      count(sel, site, species_folder) |>
        pivot_wider(names_from = species_folder, values_from = n,
                    values_fill = 0L)
    })
    output$inclusion <- shiny::renderTable({
      sel <- selected()
      shiny::req(sel, nrow(sel) > 0, any(!is.na(sel$inclusion_prob)))
      sel |>
        summarise(n = n(), min = min(inclusion_prob, na.rm = TRUE),
                  median = stats::median(inclusion_prob, na.rm = TRUE),
                  max = max(inclusion_prob, na.rm = TRUE),
                  .by = species_folder) |>
        arrange(species_folder)
    }, digits = 3)
    output$cut_status <- shiny::renderTable({
      shiny::req(status())
      status()
    })
    n_cuts
  })
}

#' UI of the Export tab
#'
#' @param id Character scalar, module id.
#' @param output_dir Character scalar, folder of the round.
#' @return A 'shiny' sidebar layout.
#' @noRd
export_ui <- function(id, output_dir) {
  ns <- shiny::NS(id)
  shiny::sidebarLayout(
    shiny::sidebarPanel(
      width = 4,
      shiny::selectInput(ns("occasion_unit"), "Occasion",
                         c("file", "minute")),
      hint("The unit of time over which a species counts as detected or",
           "not at a site. Use the one of the clip extraction."),
      shiny::numericInput(ns("min_confidence"), "Minimum score", 0.1,
                          min = 0, max = 1, step = 0.05),
      hint("Predictions below this score are left out. Use the minimum",
           "score of the BirdNET run or higher."),
      shiny::textInput(ns("export_dir"), "Export folder",
                       file.path(output_dir, "occupancy")),
      hint("Where the occupancy tables are written."),
      shiny::checkboxInput(ns("overwrite"), "Overwrite an existing export"),
      hint("Replaces an earlier export in this folder."),
      shiny::actionButton(ns("export"), "Export", class = "btn-primary"),
      shiny::helpText("The score calibration is not in the app yet: call",
                      "export_occupancy_data() with `fit` for it.")
    ),
    shiny::mainPanel(
      width = 8,
      shiny::uiOutput(ns("notes")),
      shiny::tableOutput(ns("summary")),
      shiny::tableOutput(ns("tables"))
    )
  )
}

#' Verdicts of the app for the export
#'
#' Consensus among reviewers, without the clips not reviewed.
#'
#' @param manifest Character scalar, path to the manifest.
#' @param verdicts_file Character scalar, path to the verdicts CSV.
#' @param clips_dir Character scalar, folder of the clips.
#' @return A data frame from consensus_verdicts(), or `NULL` when there is
#'   no reviewed clip.
#' @noRd
app_validation <- function(manifest, verdicts_file, clips_dir) {
  if (!file.exists(manifest) || !file.exists(verdicts_file)) return(NULL)
  v <- suppressMessages(app_verdicts(manifest, verdicts_file, clips_dir))
  v <- v[v$verdict != "not_reviewed", ]
  if (nrow(v) == 0) return(NULL)
  suppressMessages(consensus_verdicts(v))
}

#' Server of the Export tab
#'
#' @param id Character scalar, module id.
#' @param detections A data frame of BirdNET predictions.
#' @param output_dir Character scalar, folder of the round.
#' @param clips_dir Character scalar, folder of the clips.
#' @param verdicts_file Character scalar, path to the verdicts CSV.
#' @param recordings A data frame of recordings, or `NULL`.
#' @param classifier Character scalar or `NULL`, label of the classifier.
#' @return A reactive with the result of export_occupancy_data().
#' @noRd
export_server <- function(id, detections, output_dir, clips_dir,
                          verdicts_file, recordings = NULL,
                          classifier = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    export_result <- shiny::reactiveVal(NULL)
    note_lines <- shiny::reactiveVal(character())
    shiny::observeEvent(input$export, {
      validation <- app_validation(
        file.path(output_dir, "clip_manifest.csv"), verdicts_file, clips_dir)
      r <- tryCatch(
        with_notes(export_occupancy_data(
          input$export_dir, detections, recordings = recordings,
          validation = validation, occasion_unit = input$occasion_unit,
          min_confidence = input$min_confidence, classifier = classifier,
          overwrite = isTRUE(input$overwrite))),
        error = function(e) {
          list(value = NULL, notes = paste("Error:", conditionMessage(e)))
        })
      if (is.null(validation)) {
        r$notes <- c(r$notes, "No reviewed clip yet: exported without the validation tables.")
      }
      note_lines(r$notes)
      export_result(r$value)
    })
    output$notes <- shiny::renderUI({
      n <- note_lines()
      if (length(n) == 0) return(NULL)
      shiny::div(class = "alert alert-info",
                 lapply(n, function(x) shiny::p(x)))
    })
    output$summary <- shiny::renderTable({
      r <- export_result()
      shiny::req(r)
      as_field <- function(x) if (is.null(x)) NA_character_ else
        as.character(x)
      tibble(field = c("Schema", "Version", "Occasion", "Folder"),
             value = c(as_field(r$schema$schema),
                       as_field(r$schema$schema_version),
                       as_field(r$schema$occasion_unit), input$export_dir))
    }, colnames = FALSE)
    output$tables <- shiny::renderTable({
      r <- export_result()
      shiny::req(r)
      tibble(table = names(r$tables),
             rows = vapply(r$tables, nrow, integer(1)))
    })
    export_result
  })
}
