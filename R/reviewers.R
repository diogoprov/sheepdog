#' Assign the clips to several reviewers
#'
#' Splits the clips of a manifest among reviewers, balanced within each
#' species, and gives a fraction of them to a second reviewer, so that the
#' agreement between reviewers can be measured with
#' [reviewer_agreement()]. The overlap is drawn within each species, so
#' every species gets doubly reviewed clips.
#'
#' Cut the clips with [cut_clips()] first, then copy each reviewer's share
#' to their own folder with [split_by_reviewer()].
#'
#' @param manifest A data frame (or tibble), the clip manifest as returned
#'   by [select_clips()] or [cut_clips()]. One row per clip.
#' @param reviewers Character vector of length >= 2, unique names of the
#'   reviewers.
#' @param overlap Numeric scalar in \[0, 1\]. Fraction of the clips of each
#'   species reviewed by two reviewers.
#' @param seed Integer scalar, seed of the draws. The global random number
#'   generator is left as it was.
#'
#' @return The manifest with `reviewer` (the first reviewer of each clip)
#'   and `second_reviewer` (`NA` for clips reviewed once).
#' @export
assign_reviewers <- function(manifest, reviewers, overlap = 0.1,
                             seed = 2026) {
  if (length(reviewers) < 2) stop("Give at least two reviewers.")
  if (anyDuplicated(reviewers)) stop("Reviewer names must be unique.")
  if (overlap < 0 || overlap > 1) stop("`overlap` must be between 0 and 1.")
  k <- length(reviewers)
  withr::with_seed(seed, {
    manifest |>
      mutate(.row = row_number()) |>
      group_by(species_code) |>
      mutate(
        .order = sample.int(n()),
        # rotation among reviewers within the species, starting from a
        # randomly drawn reviewer
        .r1 = (.order + sample.int(k, 1) - 2) %% k + 1,
        .pair = .order <= round(overlap * n()),
        # the second reviewer is always a different one
        .r2 = (.r1 + sample.int(k - 1, n(), replace = TRUE) - 1) %% k + 1
      ) |>
      ungroup() |>
      mutate(reviewer = reviewers[.r1],
             second_reviewer = if_else(.pair, reviewers[.r2], NA_character_)) |>
      arrange(.row) |>
      select(-.row, -.order, -.r1, -.r2, -.pair)
  })
}

#' Copy each reviewer's clips to their own folder
#'
#' Copies the cut clips of a manifest with reviewers
#' ([assign_reviewers()]) to `<output_dir>/<reviewer>/<species_folder>/`,
#' one folder tree per reviewer, ready for the review tab of the BirdNET
#' GUI. Clips with a second reviewer are copied to both folders. After the
#' review, classify each reviewer's folder with [classify_review()].
#'
#' @param manifest A data frame (or tibble) returned by [assign_reviewers()],
#'   with columns `reviewer`, `second_reviewer`, `species_folder` and
#'   `clip_file`.
#' @param clips_dir Character scalar, path to the folder of the cut clips
#'   (the `clips` folder written by [cut_clips()]).
#' @param output_dir Character scalar, path to the output folder.
#'
#' @return A tibble with `reviewer`, `species_folder`, `clip_file` and `to`,
#'   invisibly.
#' @export
split_by_reviewer <- function(manifest, clips_dir, output_dir) {
  check_columns(manifest, c("reviewer", "second_reviewer"), "manifest",
                hint = "Use the manifest of assign_reviewers().")
  copies <- bind_rows(
    select(manifest, reviewer, species_folder, clip_file),
    manifest |>
      filter(!is.na(second_reviewer)) |>
      transmute(reviewer = second_reviewer, species_folder, clip_file)
  ) |>
    mutate(from = file.path(clips_dir, species_folder, clip_file),
           to = file.path(output_dir, reviewer, species_folder, clip_file))
  walk(unique(dirname(copies$to)), dir.create, recursive = TRUE,
       showWarnings = FALSE)
  ok <- file.copy(copies$from, copies$to, overwrite = TRUE)
  if (!all(ok)) warning(sum(!ok), " clip(s) not found in ", clips_dir, ".")
  message(sum(ok), " clips copied to ", n_distinct(copies$reviewer),
          " reviewer folders in ", output_dir)
  invisible(select(copies[ok, ], reviewer, species_folder, clip_file, to))
}

#' Agreement between reviewers
#'
#' Measures, for each species, the agreement between reviewers on the
#' clips reviewed more than once: the proportion of agreement and kappa,
#' which discounts the agreement expected by chance. When a species has
#' exactly two reviewers, this is Cohen's kappa, with the marginal
#' frequencies of each reviewer (Cohen 1960, \doi{10.1177/001316446002000104});
#' with more reviewers, or different pairs of reviewers on different
#' clips, Fleiss' kappa (Fleiss 1971, \doi{10.1037/h0031619}). Only
#' positive and negative verdicts count.
#'
#' @param reviews A data frame (or tibble) or a named list of data frames.
#'   One table of reviewed clips (as returned by [classify_review()]) with
#'   a `reviewer` column, or a named list of such tables, named by
#'   reviewer.
#'
#' @return A tibble with `species_folder`, `n_clips` (clips with at least
#'   two verdicts), `n_reviewers`, `agreement`, `kappa` and `method`.
#' @export
reviewer_agreement <- function(reviews) {
  long <- stack_reviews(reviews)
  multi <- long |>
    group_by(species_folder, clip_file) |>
    filter(n() >= 2) |>
    ungroup()
  if (nrow(multi) == 0) {
    warning("No clip has verdicts from two reviewers.")
    return(tibble(species_folder = character(), n_clips = integer(),
                  n_reviewers = integer(), agreement = double(),
                  kappa = double(), method = character()))
  }
  multi |>
    group_split(species_folder) |>
    map(function(df) {
      tab <- df |>
        group_by(clip_file) |>
        summarise(n_pos = sum(verdict == "positive"),
                  n_neg = sum(verdict == "negative"), .groups = "drop")
      two <- n_distinct(df$reviewer) == 2
      tibble(species_folder = df$species_folder[1],
             n_clips = nrow(tab),
             n_reviewers = n_distinct(df$reviewer),
             agreement = mean(tab$n_pos == 0 | tab$n_neg == 0),
             kappa = if (two) cohen_kappa(df) else
                       fleiss_kappa(tab$n_pos, tab$n_neg),
             method = if (two) "Cohen" else "Fleiss")
    }) |>
    list_rbind()
}

#' Consensus verdicts of several reviewers
#'
#' Combines the verdicts of several reviewers into one validation table:
#' each clip keeps the verdict its reviewers agree on; clips with
#' conflicting verdicts get `verdict = "disagreement"` and are listed for a
#' consensus review. Disagreements are left out of the precision,
#' thresholds and calibration, which use only positive and negative
#' verdicts.
#'
#' @inheritParams reviewer_agreement
#'
#' @return A tibble with one row per clip: the columns of the reviewed
#'   tables (from the first reviewer of each clip), `verdict`,
#'   `n_reviewers` and `reviewers` (names separated by `;`).
#' @export
consensus_verdicts <- function(reviews) {
  long <- stack_reviews(reviews)
  valid <- filter(long, verdict %in% c("positive", "negative"))
  clip_summary <- valid |>
    group_by(species_folder, clip_file) |>
    summarise(
      .verdict = if (n_distinct(verdict) == 1) first(verdict)
                else "disagreement",
      n_reviewers = n(),
      reviewers = paste(sort(unique(reviewer)), collapse = ";"),
      .groups = "drop")
  n_conflicts <- sum(clip_summary$.verdict == "disagreement")
  if (n_conflicts > 0) {
    message(n_conflicts, " clip(s) with conflicting verdicts marked ",
            "\"disagreement\" for a consensus review.")
  }
  long |>
    distinct(species_folder, clip_file, .keep_all = TRUE) |>
    left_join(clip_summary, by = c("species_folder", "clip_file")) |>
    mutate(verdict = coalesce(.verdict, verdict),
           n_reviewers = replace_na(n_reviewers, 0L)) |>
    select(-.verdict, -reviewer)
}

#' Stack the reviews of several reviewers into one table
#'
#' @param reviews A data frame with a `reviewer` column, or a list of data
#'   frames named by reviewer.
#' @return A data frame with one row per clip and reviewer, with column
#'   `reviewer`.
#' @noRd
stack_reviews <- function(reviews) {
  if (is.data.frame(reviews)) {
    if (!"reviewer" %in% names(reviews)) {
      stop("A single table needs a `reviewer` column.")
    }
    long <- reviews
  } else {
    if (is.null(names(reviews)) || any(names(reviews) == "")) {
      stop("A list of reviews must be named by reviewer.")
    }
    long <- imap(reviews, \(df, nm) mutate(df, reviewer = nm)) |>
      list_rbind()
  }
  long
}

#' Cohen's kappa for two reviewers
#'
#' Built from the 2 x 2 table of the verdicts of each reviewer on the clips
#' both reviewed, with the marginal frequencies of each reviewer.
#'
#' @param df A data frame with columns `clip_file`, `reviewer` (exactly two
#'   distinct values) and `verdict`.
#' @return Numeric scalar, kappa; `NA` with no shared clip or when the
#'   expected agreement is 1.
#' @noRd
cohen_kappa <- function(df) {
  revs <- sort(unique(df$reviewer))
  wide <- df |>
    select(clip_file, reviewer, verdict) |>
    pivot_wider(names_from = reviewer, values_from = verdict) |>
    filter(!is.na(.data[[revs[1]]]), !is.na(.data[[revs[2]]]))
  a <- wide[[revs[1]]] == "positive"
  b <- wide[[revs[2]]] == "positive"
  if (length(a) == 0) return(NA_real_)
  p_o <- mean(a == b)
  p_e <- mean(a) * mean(b) + (1 - mean(a)) * (1 - mean(b))
  if (near(p_e, 1)) return(NA_real_)
  (p_o - p_e) / (1 - p_e)
}

#' Fleiss' kappa from the counts of verdicts per clip
#'
#' Accepts different reviewers on different clips; clips with fewer than
#' two verdicts are dropped.
#'
#' @param n_pos,n_neg Integer vectors of equal length, numbers of positive
#'   and negative verdicts of each clip.
#' @return Numeric scalar, kappa; `NA` with no usable clip or when the
#'   expected agreement is 1.
#' @noRd
fleiss_kappa <- function(n_pos, n_neg) {
  n <- n_pos + n_neg
  ok <- n >= 2
  n_pos <- n_pos[ok]; n_neg <- n_neg[ok]; n <- n[ok]
  if (length(n) == 0) return(NA_real_)
  p_i <- (n_pos * (n_pos - 1) + n_neg * (n_neg - 1)) / (n * (n - 1))
  p_bar <- mean(p_i)
  p_pos <- sum(n_pos) / sum(n)
  p_e <- p_pos^2 + (1 - p_pos)^2
  if (near(p_e, 1)) return(NA_real_)
  (p_bar - p_e) / (1 - p_e)
}
