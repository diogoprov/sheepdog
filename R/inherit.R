# Reuse of the review of another design (#102): the draw stays independent,
# and only the verdict the previous review already gives is inherited

#' Inherit verdicts from the review of another design
#'
#' Two reviews cover the same stretch when they share site, species and
#' recording and their intervals overlap, which covers different units
#' (minute and file):
#' * heard absent -> every prediction in the stretch is negative;
#' * positive prediction -> the recording or minute has the species.
#' The converse does not hold: present by ear does not say which prediction
#' is true, and negative predictions do not say that the species did not call
#' below the threshold.
#'
#' @param selection A data frame of selected clips, with columns `site`,
#'   `species_code`, `source_audio`, `clip_start` and `clip_end`.
#' @param others A data frame of reviewed clips of the other design (its
#'   `validation_by_clip.csv`), with the same columns plus `verdict` and
#'   `sampling_mode`.
#' @param mode Character scalar, the sampling mode of `selection`.
#' @return `selection` with columns `previously_reviewed`,
#'   `inherited_verdict` and `source_design` added.
#' @noRd
inherit_verdicts <- function(selection, others, mode) {
  if (!"verdict" %in% names(others)) {
    stop("`previous` of another design must have the verdicts: give its ",
         "validation_by_clip.csv.", call. = FALSE)
  }
  reviewed <- others |>
    filter(verdict %in% c("positive", "negative"))
  if ("inherited_verdict" %in% names(reviewed)) {
    reviewed <- filter(reviewed, is.na(inherited_verdict))
  }
  reviewed <- reviewed |>
    transmute(site = as.character(site), species_code,
              .rec = recording_name(source_audio),
              .start = as.numeric(clip_start),
              .end = coalesce(as.numeric(clip_end), Inf),
              .negative = verdict == "negative", .design = sampling_mode)
  overlap <- selection |>
    transmute(.row = row_number(), site = as.character(site), species_code,
              .rec = recording_name(source_audio),
              .a = as.numeric(clip_start),
              .b = coalesce(as.numeric(clip_end), Inf)) |>
    inner_join(reviewed, by = c("site", "species_code", ".rec"),
               relationship = "many-to-many") |>
    filter(.a < .end, .start < .b) |>
    group_by(.row) |>
    summarise(.all_neg = all(.negative), .any_pos = any(!.negative),
              .design = first(.design), .groups = "drop")
  selection$previously_reviewed <- FALSE
  selection$inherited_verdict <- NA_character_
  selection$source_design <- NA_character_
  selection$previously_reviewed[overlap$.row] <- TRUE
  selection$source_design[overlap$.row] <- overlap$.design
  selection$inherited_verdict[overlap$.row] <- if (mode == "random_detections") {
    if_else(overlap$.all_neg, "negative", NA_character_)
  } else {
    if_else(overlap$.any_pos, "positive", NA_character_)
  }
  selection
}

#' Recording name from an audio path
#'
#' @param path Character vector of file paths (Windows or POSIX separators).
#' @return Character vector, the base names without extension.
#' @noRd
recording_name <- function(path) {
  tools::file_path_sans_ext(basename(chartr("\\", "/", path)))
}

#' Fill unreviewed clips with the inherited verdict
#'
#' Clips without their own verdict get the inherited one; a verdict actually
#' given prevails, and the clip stops being inherited. Inherited clips have
#' no cut clip, so their `reviewed_path` is cleared.
#'
#' @param table A data frame of clips with `verdict` and, optionally,
#'   `inherited_verdict` and `reviewed_path`.
#' @return `table` with `verdict` filled and `inherited_verdict` updated.
#' @noRd
fill_inherited <- function(table) {
  if (!"inherited_verdict" %in% names(table)) return(table)
  table$inherited_verdict <- as.character(table$inherited_verdict)
  reviewed <- table$verdict %in% c("positive", "negative", "uncertain")
  table$inherited_verdict[reviewed] <- NA_character_
  inherited <- !is.na(table$inherited_verdict)
  table$verdict[inherited] <- table$inherited_verdict[inherited]
  if ("reviewed_path" %in% names(table)) {
    table$reviewed_path[inherited] <- NA_character_
  }
  table
}

#' Flag inherited rows of a manifest or validation table
#'
#' @param table A data frame, optionally with `inherited_verdict`.
#' @return Logical vector with one element per row of `table`.
#' @noRd
is_inherited <- function(table) {
  if (!"inherited_verdict" %in% names(table)) {
    return(rep(FALSE, nrow(table)))
  }
  !is.na(table$inherited_verdict)
}
