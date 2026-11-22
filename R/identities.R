#' Join identities of negative clips recorded outside the app
#'
#' Adds to a table of verdicts the identity of negative (and uncertain)
#' clips that a reviewer wrote elsewhere, for example in a spreadsheet with
#' one row per clip. The identities given in [run_app()] are kept: an
#' external identity only fills clips without one, and a clip where the two
#' differ is reported.
#'
#' @param validation A data frame (or tibble) of verdicts with `clip_file`
#'   and `verdict`, from [app_verdicts()], [classify_review()] or
#'   [consensus_verdicts()].
#' @param identities A data frame (or tibble), or a character scalar with
#'   the path to a CSV, with one row per clip. Read a spreadsheet with
#'   `readxl::read_excel()` first.
#' @param clip_col,identity_col Character scalars, the columns of
#'   `identities` with the clip name (as in `clip_file`; a path is reduced
#'   to its file name) and the identity.
#' @param certainty_col `NULL` or a character scalar, the column of
#'   `identities` with the certainty, `"sure"` or `"probable"`. Without it,
#'   the certainty is left `NA`.
#' @param reviewer `NULL` or a character vector of reviewer names: with a
#'   table that has one row per clip and reviewer, only those reviewers'
#'   rows receive the identities.
#'
#' @details
#' Identities are trimmed of spaces; several identities of one clip,
#' separated by `|`, mean either of them. Warnings list the clips of
#' `identities` that are not in `validation` and the clips that received
#' an identity although their verdict is neither negative nor uncertain (a
#' sign that the verdict or the identity is wrong). A message gives how
#' many negative clips are still without an identity.
#'
#' @return `validation` with `identity` and `identity_certainty` filled.
#' @seealso [run_app()], [confuser_summary()], [identity_categories()].
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read.csv(file.path(ex, "validation", "validation_by_clip_ARA.csv"))
#' # Identities of two negative clips, written in a spreadsheet
#' neg <- val$clip_file[val$verdict == "negative"][1:2]
#' ids <- data.frame(clip = neg, identity = c("insect", "bird|noise"),
#'                   certainty = c("sure", "probable"))
#' val <- join_identities(val, ids, certainty_col = "certainty")
#' val[val$clip_file %in% neg,
#'     c("clip_file", "verdict", "identity", "identity_certainty")]
#' @export
join_identities <- function(validation, identities, clip_col = "clip",
                            identity_col = "identity",
                            certainty_col = NULL, reviewer = NULL) {
  if (is.character(identities)) {
    identities <- read_csv(identities, show_col_types = FALSE,
                           col_types = cols(.default = col_character()))
  }
  check_columns(identities, c(clip_col, identity_col, certainty_col),
                "identities")
  check_columns(validation, c("clip_file", "verdict"), "validation")
  ext <- tibble(
    clip_file = basename(as.character(identities[[clip_col]])),
    .id = vapply(as.character(identities[[identity_col]]), clean_identity,
                 character(1), USE.NAMES = FALSE),
    .certainty = if (is.null(certainty_col)) NA_character_ else
      as.character(identities[[certainty_col]]))
  ext <- filter(ext, !is.na(.id))
  invalid <- setdiff(stats::na.omit(ext$.certainty), identity_certainties)
  if (length(invalid) > 0) {
    stop("Unknown certainty value(s) in `identities`: ",
         paste(invalid, collapse = ", "), " (use \"sure\" or ",
         "\"probable\").", call. = FALSE)
  }
  dups <- unique(ext$clip_file[duplicated(ext$clip_file)])
  if (length(dups) > 0) {
    stop("Clip(s) with more than one row in `identities`: ",
         paste(utils::head(dups, 5), collapse = ", "),
         if (length(dups) > 5) ", ...", call. = FALSE)
  }
  outside <- setdiff(ext$clip_file, validation$clip_file)
  if (length(outside) > 0) {
    warning(length(outside), " clip(s) of `identities` are not in ",
            "`validation`: ", paste(utils::head(outside, 5), collapse = ", "),
            if (length(outside) > 5) ", ...", call. = FALSE)
  }
  for (col in identity_columns) {
    if (!col %in% names(validation)) validation[[col]] <- NA_character_
  }
  target <- if (is.null(reviewer) || !"reviewer" %in% names(validation)) {
    rep(TRUE, nrow(validation))
  } else {
    validation$reviewer %in% reviewer
  }
  pos <- match(validation$clip_file, ext$clip_file)
  pos[!target] <- NA_integer_
  new_id <- ext$.id[pos]
  conflict <- !is.na(new_id) & !is.na(validation$identity) &
    validation$identity != new_id
  if (any(conflict)) {
    warning(sum(conflict), " clip(s) already have a different identity ",
            "from the app, which was kept: ",
            paste(utils::head(validation$clip_file[conflict], 5),
                  collapse = ", "),
            if (sum(conflict) > 5) ", ...", call. = FALSE)
  }
  to_fill <- !is.na(new_id) & is.na(validation$identity)
  validation$identity[to_fill] <- new_id[to_fill]
  validation$identity_certainty[to_fill] <- ext$.certainty[pos][to_fill]
  has_id <- !is.na(new_id)
  odd <- has_id & !validation$verdict %in% c("negative", "uncertain")
  if (any(odd)) {
    warning(sum(odd), " clip(s) received an identity but their ",
            "verdict is not negative or uncertain; check them: ",
            paste(utils::head(paste0(validation$clip_file[odd], " (",
                                     validation$verdict[odd], ")"), 5),
                  collapse = ", "),
            if (sum(odd) > 5) ", ...", call. = FALSE)
  }
  negatives <- target & validation$verdict == "negative"
  message(sum(negatives & !is.na(validation$identity)), " of ",
          sum(negatives), " negative clip(s) with an identity.")
  validation
}

#' What the false positives of each class are
#'
#' Counts, for each target class, the identities given to its negative
#' clips (and, optionally, its uncertain clips): the sounds the classifier
#' confuses with the target. The table points to hard negatives for
#' retraining and shows when a negative of one class is a positive of
#' another class of the classifier.
#'
#' @param validation A data frame (or tibble) of verdicts with
#'   `species_code`, `verdict` and `identity`, from [app_verdicts()] or
#'   [join_identities()].
#' @param verdicts Character vector of one or more verdicts counted, among
#'   `"negative"`, `"uncertain"`, `"positive"`, `"disagreement"` and
#'   `"not_reviewed"`: `"negative"` by default; add `"uncertain"` to include
#'   the uncertain clips.
#' @param classes `NULL` or a character vector of the classes of the
#'   classifier, to flag identities that are classes themselves. `NULL`
#'   (default) uses the `species_code` values of `validation`.
#'
#' @details
#' A clip with several identities (`"a|b"`) counts once for each of them,
#' with weight `1 / k` in `n_weighted` for `k` identities, so that
#' `n_weighted` sums to the number of clips with an identity. Clips without
#' an identity are counted as `identity = NA`.
#'
#' @return A tibble (class `tbl_df`) with one row per target class and
#'   identity: `species_code`, `identity`, `n` (clips), `n_weighted`,
#'   `n_sure` (clips with certainty `"sure"`), `share` (`n_weighted` over
#'   the clips of the class counted) and `is_class` (the identity is a class
#'   of the classifier other than the target), sorted by class and
#'   decreasing `n`.
#' @seealso [join_identities()], [build_training_set()].
#' @examples
#' ex <- system.file("extdata", "example", package = "sheepdog")
#' val <- read.csv(file.path(ex, "validation", "validation_by_clip_ARA.csv"))
#' neg <- val$clip_file[val$verdict == "negative"][1:3]
#' ids <- data.frame(clip = neg, identity = c("insect", "insect", "bird|rain"))
#' val <- join_identities(val, ids)
#' confuser_summary(val)
#' @export
confuser_summary <- function(validation, verdicts = "negative",
                             classes = NULL) {
  known <- c("negative", "uncertain", "positive", "disagreement",
             "not_reviewed")
  if (!is.character(verdicts) || length(verdicts) == 0 ||
      !all(verdicts %in% known)) {
    stop("`verdicts` must be one or more of: ",
         paste0("\"", known, "\"", collapse = ", "), ".", call. = FALSE)
  }
  check_columns(validation, c("species_code", "verdict", "identity"),
                "validation")
  if (is.null(classes)) {
    classes <- unique(stats::na.omit(as.character(validation$species_code)))
  }
  if (!"identity_certainty" %in% names(validation)) {
    validation$identity_certainty <- NA_character_
  }
  sel <- filter(validation, verdict %in% verdicts)
  n_class <- count(sel, species_code, name = ".n_class")
  sel |>
    mutate(.ids = strsplit(identity, "|", fixed = TRUE),
           .k = lengths(.ids)) |>
    unnest_longer(.ids, values_to = "identity_one", keep_empty = TRUE) |>
    mutate(.weight = 1 / pmax(.k, 1)) |>
    group_by(species_code, identity = identity_one) |>
    summarise(n = n(), n_weighted = sum(.weight),
              n_sure = sum(identity_certainty %in% "sure"),
              .groups = "drop") |>
    left_join(n_class, by = "species_code") |>
    mutate(share = n_weighted / .n_class,
           is_class = !is.na(identity) & identity %in% classes &
             identity != species_code) |>
    select(-.n_class) |>
    arrange(species_code, desc(n), identity)
}
