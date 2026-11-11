#' Join identities of negative clips recorded outside the app
#'
#' Adds to a table of verdicts the identity of negative (and uncertain)
#' clips that a reviewer wrote elsewhere, for example in a spreadsheet with
#' one row per clip. The identities given in [run_app()] are kept: an
#' external identity only fills clips without one, and a clip where the two
#' differ is reported.
#'
#' @param validation Table of verdicts with `clip_file` and `verdict`, from
#'   [app_verdicts()], [classify_review()] or [consensus_verdicts()].
#' @param identities Data frame, or the path to a CSV, with one row per
#'   clip. Read a spreadsheet with `readxl::read_excel()` first.
#' @param clip_col,identity_col Columns of `identities` with the clip name
#'   (as in `clip_file`; a path is reduced to its file name) and the
#'   identity.
#' @param certainty_col Optional column of `identities` with the certainty,
#'   `"sure"` or `"probable"`. Without it, the certainty is left `NA`.
#' @param reviewer Optional reviewer: with a table that has one row per
#'   clip and reviewer, only that reviewer's rows receive the identities.
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
#' @export
join_identities <- function(validation, identities, clip_col = "clip",
                            identity_col = "identity",
                            certainty_col = NULL, reviewer = NULL) {
  if (is.character(identities)) {
    identities <- read_csv(identities, show_col_types = FALSE,
                           col_types = cols(.default = col_character()))
  }
  faltam <- setdiff(c(clip_col, identity_col, certainty_col),
                    names(identities))
  if (length(faltam) > 0) {
    stop("`identities` lacks the column(s): ", paste(faltam, collapse = ", "),
         call. = FALSE)
  }
  faltam <- setdiff(c("clip_file", "verdict"), names(validation))
  if (length(faltam) > 0) {
    stop("`validation` lacks the column(s): ", paste(faltam, collapse = ", "),
         call. = FALSE)
  }
  ext <- tibble(
    clip_file = basename(as.character(identities[[clip_col]])),
    .id = vapply(as.character(identities[[identity_col]]), clean_identity,
                 character(1), USE.NAMES = FALSE),
    .certeza = if (is.null(certainty_col)) NA_character_ else
      as.character(identities[[certainty_col]]))
  ext <- filter(ext, !is.na(.id))
  invalidas <- setdiff(stats::na.omit(ext$.certeza), identity_certainties)
  if (length(invalidas) > 0) {
    stop("Unknown certainty value(s) in `identities`: ",
         paste(invalidas, collapse = ", "), " (use \"sure\" or ",
         "\"probable\").", call. = FALSE)
  }
  repetidos <- unique(ext$clip_file[duplicated(ext$clip_file)])
  if (length(repetidos) > 0) {
    stop("Clip(s) with more than one row in `identities`: ",
         paste(utils::head(repetidos, 5), collapse = ", "),
         if (length(repetidos) > 5) ", ...", call. = FALSE)
  }
  fora <- setdiff(ext$clip_file, validation$clip_file)
  if (length(fora) > 0) {
    warning(length(fora), " clip(s) of `identities` are not in ",
            "`validation`: ", paste(utils::head(fora, 5), collapse = ", "),
            if (length(fora) > 5) ", ...", call. = FALSE)
  }
  for (col in identity_columns) {
    if (!col %in% names(validation)) validation[[col]] <- NA_character_
  }
  alvo <- if (is.null(reviewer) || !"reviewer" %in% names(validation)) {
    rep(TRUE, nrow(validation))
  } else {
    validation$reviewer %in% reviewer
  }
  pos <- match(validation$clip_file, ext$clip_file)
  pos[!alvo] <- NA_integer_
  novo <- ext$.id[pos]
  conflito <- !is.na(novo) & !is.na(validation$identity) &
    validation$identity != novo
  if (any(conflito)) {
    warning(sum(conflito), " clip(s) already have a different identity ",
            "from the app, which was kept: ",
            paste(utils::head(validation$clip_file[conflito], 5),
                  collapse = ", "),
            if (sum(conflito) > 5) ", ...", call. = FALSE)
  }
  preencher <- !is.na(novo) & is.na(validation$identity)
  validation$identity[preencher] <- novo[preencher]
  validation$identity_certainty[preencher] <- ext$.certeza[pos][preencher]
  com_id <- !is.na(novo)
  estranhos <- com_id & !validation$verdict %in% c("negative", "uncertain")
  if (any(estranhos)) {
    warning(sum(estranhos), " clip(s) received an identity but their ",
            "verdict is not negative or uncertain; check them: ",
            paste(utils::head(paste0(validation$clip_file[estranhos], " (",
                                     validation$verdict[estranhos], ")"), 5),
                  collapse = ", "),
            if (sum(estranhos) > 5) ", ...", call. = FALSE)
  }
  negativos <- alvo & validation$verdict == "negative"
  message(sum(negativos & !is.na(validation$identity)), " of ",
          sum(negativos), " negative clip(s) with an identity.")
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
#' @param validation Table of verdicts with `species_code`, `verdict` and
#'   `identity`, from [app_verdicts()] or [join_identities()].
#' @param verdicts Verdicts counted: `"negative"` by default; add
#'   `"uncertain"` to include the uncertain clips.
#' @param classes Classes of the classifier, to flag identities that are
#'   classes themselves. By default, the `species_code` values of
#'   `validation`.
#'
#' @details
#' A clip with several identities (`"a|b"`) counts once for each of them,
#' with weight `1 / k` in `n_weighted` for `k` identities, so that
#' `n_weighted` sums to the number of clips with an identity. Clips without
#' an identity are counted as `identity = NA`.
#'
#' @return A tibble with one row per target class and identity:
#'   `species_code`, `identity`, `n` (clips), `n_weighted`, `n_sure` (clips
#'   with certainty `"sure"`), `share` (`n_weighted` over the clips of the
#'   class counted) and `is_class` (the identity is a class of the
#'   classifier other than the target), sorted by class and decreasing `n`.
#' @seealso [join_identities()], [build_training_set()].
#' @export
confuser_summary <- function(validation, verdicts = "negative",
                             classes = NULL) {
  faltam <- setdiff(c("species_code", "verdict", "identity"),
                    names(validation))
  if (length(faltam) > 0) {
    stop("`validation` lacks the column(s): ", paste(faltam, collapse = ", "),
         call. = FALSE)
  }
  if (is.null(classes)) {
    classes <- unique(stats::na.omit(as.character(validation$species_code)))
  }
  if (!"identity_certainty" %in% names(validation)) {
    validation$identity_certainty <- NA_character_
  }
  sel <- filter(validation, verdict %in% verdicts)
  n_classe <- count(sel, species_code, name = ".n_classe")
  sel |>
    mutate(.ids = strsplit(identity, "|", fixed = TRUE),
           .k = lengths(.ids)) |>
    unnest_longer(.ids, values_to = "identity_one", keep_empty = TRUE) |>
    mutate(.peso = 1 / pmax(.k, 1)) |>
    group_by(species_code, identity = identity_one) |>
    summarise(n = n(), n_weighted = sum(.peso),
              n_sure = sum(identity_certainty %in% "sure"),
              .groups = "drop") |>
    left_join(n_classe, by = "species_code") |>
    mutate(share = n_weighted / .n_classe,
           is_class = !is.na(identity) & identity %in% classes &
             identity != species_code) |>
    select(-.n_classe) |>
    arrange(species_code, desc(n), identity)
}
