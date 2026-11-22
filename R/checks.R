# Input checks shared by the exported functions (rOpenSci standards G2).
# Each check stops with a message that names the argument; none of them
# changes a valid input, except check_file_ext(), which adds a missing
# extension, and check_validations(), which returns a plain tibble.

#' Check a single finite number within bounds
#'
#' Optionally an integer; `open` excludes the bounds.
#'
#' @param x Value to check.
#' @param arg Character scalar, argument name used in the error message.
#' @param lower,upper Numeric scalars, bounds of the allowed interval.
#' @param integer Logical scalar; if `TRUE`, `x` must be a whole number.
#' @param open Logical scalar; if `TRUE`, the bounds are excluded.
#' @param null_ok Logical scalar; if `TRUE`, `NULL` is accepted.
#' @return `x` without classes, invisibly; stops if the check fails.
#' @noRd
check_number <- function(x, arg, lower = -Inf, upper = Inf, integer = FALSE,
                         open = FALSE, null_ok = FALSE) {
  if (null_ok && is.null(x)) return(invisible(x))
  x <- unclass(x)
  ok <- is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x)
  if (ok && integer) ok <- abs(x - round(x)) < sqrt(.Machine$double.eps)
  if (ok) ok <- if (open) x > lower && x < upper else x >= lower && x <= upper
  if (!ok) {
    kind <- if (integer) "a whole number" else "a number"
    lim <- if (is.finite(lower) && is.finite(upper)) {
      paste0(if (open) " strictly" else "", " between ", lower, " and ",
             upper)
    } else if (is.finite(lower)) {
      paste0(if (open) " greater than " else " of at least ", lower)
    } else if (is.finite(upper)) {
      paste0(if (open) " less than " else " of at most ", upper)
    } else ""
    stop("`", arg, "` must be ", kind, lim, " (a single value).",
         call. = FALSE)
  }
  invisible(x)
}

#' Check a single probability
#'
#' @param x Value to check, in \[0, 1\] (or (0, 1) with `open = TRUE`).
#' @param arg Character scalar, argument name used in the error message.
#' @param open Logical scalar; if `TRUE`, 0 and 1 are excluded.
#' @param null_ok Logical scalar; if `TRUE`, `NULL` is accepted.
#' @return `x`, invisibly; stops if the check fails.
#' @noRd
check_prob <- function(x, arg, open = FALSE, null_ok = FALSE) {
  check_number(x, arg, lower = 0, upper = 1, open = open, null_ok = null_ok)
}

#' Check a TRUE or FALSE flag
#'
#' @param x Value to check.
#' @param arg Character scalar, argument name used in the error message.
#' @return `x`, invisibly; stops unless `x` is `TRUE` or `FALSE`.
#' @noRd
check_flag <- function(x, arg) {
  if (!(isTRUE(x) || isFALSE(x))) {
    stop("`", arg, "` must be TRUE or FALSE.", call. = FALSE)
  }
  invisible(x)
}

#' Check a single character string
#'
#' @param x Value to check.
#' @param arg Character scalar, argument name used in the error message.
#' @param null_ok Logical scalar; if `TRUE`, `NULL` is accepted.
#' @return `x`, invisibly; stops unless `x` is one non-missing, non-empty
#'   string (or `NULL` with `null_ok = TRUE`).
#' @noRd
check_string <- function(x, arg, null_ok = FALSE) {
  if (null_ok && is.null(x)) return(invisible(x))
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    stop("`", arg, "` must be a single character string.", call. = FALSE)
  }
  invisible(x)
}

#' Check confidence scores
#'
#' Numeric, no NaN or Inf, within \[0, 1\]. Missing values are allowed;
#' the caller decides what to do with them.
#'
#' @param x Numeric vector of BirdNET confidence scores.
#' @param arg Character scalar, argument name used in the error message.
#' @return `x` as a plain numeric vector, invisibly.
#' @noRd
check_confidence <- function(x, arg = "confidence") {
  x <- unclass(x)
  if (!is.numeric(x)) {
    stop("`", arg, "` must be numeric; it is of class ",
         paste(class(x), collapse = "/"), ".", call. = FALSE)
  }
  if (any(is.nan(x) | is.infinite(x))) {
    stop("`", arg, "` has NaN or infinite values; BirdNET scores lie ",
         "between 0 and 1.", call. = FALSE)
  }
  outside <- !is.na(x) & (x < 0 | x > 1)
  if (any(outside)) {
    stop("`", arg, "` has ", sum(outside), " value(s) outside 0 to 1 (e.g. ",
         signif(x[outside][1], 4), "); BirdNET scores lie between 0 and 1.",
         call. = FALSE)
  }
  invisible(as.numeric(x))
}

#' Check a table of reviewed clips for the calibration functions
#'
#' @param validations A data frame (tibble, data.frame or data.table) with
#'   the columns `cols`.
#' @param cols Character vector, required column names.
#' @param arg Character scalar, argument name used in the error messages.
#' @return A plain tibble in which numeric columns have lost extra classes
#'   (such as 'units'), `site` and `species` are unordered factors and `tp`
#'   is an integer 0/1.
#' @noRd
check_validations <- function(validations, cols = c("site", "species",
                                                    "logit_conf", "tp"),
                              arg = "validations") {
  if (!is.data.frame(validations)) {
    stop("`", arg, "` must be a data frame, such as the table returned by ",
         "read_validations().", call. = FALSE)
  }
  absent <- setdiff(cols, names(validations))
  if (length(absent) > 0) {
    stop("`", arg, "` lacks the column(s) ", paste(absent, collapse = ", "),
         "; see read_validations().", call. = FALSE)
  }
  val <- tibble::as_tibble(as.data.frame(validations))
  list_cols <- cols[map_lgl(cols, function(cl) is.list(val[[cl]]))]
  if (length(list_cols) > 0) {
    stop_list_columns(list_cols, arg)
  }
  if (nrow(val) == 0) {
    stop("`", arg, "` has no rows.", call. = FALSE)
  }
  for (cl in intersect(c("confidence", "logit_conf"), cols)) {
    if (!is.numeric(unclass(val[[cl]]))) {
      stop_not_numeric(cl, arg)
    }
    val[[cl]] <- as.numeric(unclass(val[[cl]]))
    if (any(is.nan(val[[cl]]) | is.infinite(val[[cl]]))) {
      stop("Column `", cl, "` of `", arg, "` has NaN or infinite values.",
           call. = FALSE)
    }
  }
  if ("confidence" %in% cols) check_confidence(val$confidence)
  if ("tp" %in% cols) {
    tp <- unclass(val$tp)
    if (is.logical(tp)) tp <- as.integer(tp)
    if (!is.numeric(tp) || any(!is.na(tp) & !tp %in% c(0, 1))) {
      stop("Column `tp` of `", arg, "` must be 0 (false positive) or 1 ",
           "(true positive).", call. = FALSE)
    }
    val$tp <- as.integer(tp)
  }
  for (cl in intersect(c("site", "species"), cols)) {
    x <- val[[cl]]
    if (is.ordered(x)) {
      message("Column `", cl, "` of `", arg, "` is an ordered factor; ",
              "it is used as an unordered factor.")
      x <- factor(as.character(x), levels = levels(x))
    } else if (is.character(x)) {
      x <- factor(x)
    } else if (!is.factor(x)) {
      stop("Column `", cl, "` of `", arg, "` must be a factor or a ",
           "character vector.", call. = FALSE)
    }
    val[[cl]] <- x
  }
  val
}

#' Stop on list columns
#'
#' Error shared by check_validations() and as_input_table().
#'
#' @param cols Character vector, names of the offending columns.
#' @param arg Character scalar, argument name used in the error message.
#' @return Does not return; always stops.
#' @noRd
stop_list_columns <- function(cols, arg) {
  stop("Column(s) ", paste(cols, collapse = ", "), " of `", arg,
       "` are list columns; give one value per row.", call. = FALSE)
}

#' Stop on a non-numeric column
#'
#' Error shared by check_validations() and as_input_table().
#'
#' @param col Character scalar, name of the offending column.
#' @param arg Character scalar, argument name used in the error message.
#' @return Does not return; always stops.
#' @noRd
stop_not_numeric <- function(col, arg) {
  stop("Column `", col, "` of `", arg, "` must be numeric.", call. = FALSE)
}

#' Missing-value policy of the package
#'
#' Read from the option `sheepdog.missing`: "omit" (default) leaves the
#' incomplete rows out with a message, "error" stops. Imputation is never
#' offered (see G2.14c).
#'
#' @return Character scalar, "omit" or "error".
#' @noRd
missing_policy <- function() {
  p <- getOption("sheepdog.missing", "omit")
  if (!is.character(p) || length(p) != 1L || !p %in% c("omit", "error")) {
    stop("Option `sheepdog.missing` must be \"omit\" or \"error\".",
         call. = FALSE)
  }
  p
}

#' Drop rows with missing values following missing_policy()
#'
#' Rows with missing values in `vars` are left out with a message, or
#' raise an error.
#'
#' @param val A data frame.
#' @param vars Character vector, columns checked for missing values; those
#'   absent from `val` are ignored.
#' @param arg Character scalar, argument name used in the messages.
#' @param allow_empty Logical scalar; if `TRUE`, returns zero rows instead
#'   of stopping when no row is complete.
#' @return `val` without the incomplete rows.
#' @noRd
drop_missing <- function(val, vars, arg = "validations",
                         allow_empty = FALSE) {
  vars <- intersect(vars, names(val))
  incomplete <- !stats::complete.cases(val[vars])
  if (any(incomplete)) {
    if (missing_policy() == "error") {
      stop("`", arg, "` has ", sum(incomplete), " row(s) with missing values ",
           "in ", paste(vars, collapse = ", "), " (option sheepdog.missing ",
           "= \"error\").", call. = FALSE)
    }
    message(sum(incomplete), " row(s) of `", arg, "` with missing values in ",
            paste(vars, collapse = ", "), " were left out.")
    val <- val[!incomplete, , drop = FALSE]
  }
  if (nrow(val) == 0 && !allow_empty) {
    stop("No row of `", arg, "` is complete.", call. = FALSE)
  }
  val
}

#' Entry routine for the tables of the sampling and threshold functions
#'
#' Implements G2.6-G2.8, G2.11 and G2.12: any data frame (data.frame,
#' tibble, data.table) becomes a plain tibble; the used columns may not be
#' list columns; numeric columns lose extra classes such as 'units'.
#'
#' @param x A data frame.
#' @param cols Character vector, required column names.
#' @param arg Character scalar, argument name used in the error messages.
#' @param numeric Character vector, columns coerced to plain numeric.
#' @return A plain tibble.
#' @noRd
as_input_table <- function(x, cols, arg, numeric = character()) {
  check_data_frame(x, arg)
  check_columns(x, cols, arg)
  x <- tibble::as_tibble(as.data.frame(x))
  used <- intersect(unique(c(cols, numeric)), names(x))
  list_cols <- used[map_lgl(used, function(cl) is.list(x[[cl]]))]
  if (length(list_cols) > 0) {
    stop_list_columns(list_cols, arg)
  }
  for (cl in intersect(numeric, names(x))) {
    v <- unclass(x[[cl]])
    if (!is.numeric(v) && !all(is.na(v))) {
      stop_not_numeric(cl, arg)
    }
    x[[cl]] <- as.numeric(v)
  }
  x
}

#' Check a table of BirdNET predictions
#'
#' Used by select_clips(), select_directed() and threshold_history(): the
#' entry routine, then rows without a confidence or an audio path follow
#' missing_policy().
#'
#' @param detections A data frame of predictions.
#' @param cols Character vector, required column names.
#' @param arg Character scalar, argument name used in the messages.
#' @return A plain tibble with the complete rows.
#' @noRd
check_detections <- function(detections, cols, arg = "detections") {
  det <- as_input_table(detections, cols, arg,
                        numeric = c("confidence", "begin_time", "end_time",
                                    "file_offset"))
  drop_missing(det, c("confidence", "begin_path"), arg)
}

#' Fixed part of a formula with random effects
#'
#' @param formula A formula in the syntax of 'lme4'.
#' @return A formula with the same response and only the fixed terms
#'   (an intercept if there is none).
#' @noRd
fixed_formula <- function(formula) {
  tl <- attr(stats::terms(formula), "term.labels")
  fixed <- tl[!grepl("|", tl, fixed = TRUE)]
  resp <- all.vars(formula)[1]
  if (length(fixed) == 0) return(stats::reformulate("1", response = resp))
  stats::reformulate(fixed, response = resp)
}

#' Check the data against a calibration formula before the fit
#'
#' Checks the rank of the fixed-effects model matrix (RE2.4a), a response
#' with both classes, grouping factors with one level per clip, and
#' complete separation of `tp` by `logit_conf` (RE2.4b).
#'
#' @param val A data frame of reviewed clips with column `tp`.
#' @param formula A calibration formula in the syntax of 'lme4'.
#' @return `val`, invisibly; stops, warns or messages on problems.
#' @noRd
check_calibration_data <- function(val, formula) {
  if (n_distinct(val$tp) < 2L) {
    stop("All the reviewed clips have the same verdict (tp = ", val$tp[1],
         "); a calibration model needs true and false positives.",
         call. = FALSE)
  }
  x <- stats::model.matrix(fixed_formula(formula), data = val)
  mm_rank <- qr(x)$rank
  if (mm_rank < ncol(x)) {
    stop("The fixed effects of ", deparse1(formula), " are collinear ",
         "(model matrix of rank ", mm_rank, " with ", ncol(x), " columns); ",
         "drop or combine the redundant terms.", call. = FALSE)
  }
  # grouping factors of the random effects: a level per reviewed clip
  # makes the variance of a binary response unidentifiable (RE2.4, G5.8d)
  tl <- attr(stats::terms(formula), "term.labels")
  groups <- unique(unlist(lapply(tl[grepl("|", tl, fixed = TRUE)],
                                 function(t) {
    all.vars(str2lang(sub("^.*\\|", "", t)))
  })))
  for (g in intersect(groups, names(val))) {
    if (n_distinct(val[[g]]) == nrow(val)) {
      stop("Each level of `", g, "` has a single reviewed clip: the ",
           "variance of its random effect cannot be estimated from binary ",
           "verdicts. Drop the term or group the levels.", call. = FALSE)
    }
  }
  if ("logit_conf" %in% names(val)) {
    separated <- function(tp, s) {
      length(unique(tp)) == 2L &&
        (max(s[tp == 0]) < min(s[tp == 1]) || max(s[tp == 1]) < min(s[tp == 0]))
    }
    if (separated(val$tp, val$logit_conf)) {
      warning("The verdicts are completely separated by the score (every ",
              "true positive scores above every false positive, or the ",
              "reverse): the maximum likelihood slope is infinite. Review ",
              "more clips near the boundary, or use engine = \"brms\" with ",
              "a prior.", call. = FALSE)
    }
    if ("species" %in% names(val) && n_distinct(val$species) > 1L) {
      by_sp <- split(val, val$species, drop = TRUE)
      single <- names(by_sp)[map_lgl(by_sp, function(d) n_distinct(d$tp) < 2L)]
      sep <- names(by_sp)[map_lgl(by_sp, function(d) {
        separated(d$tp, d$logit_conf)
      })]
      if (length(single) > 0) {
        message("Species with a single verdict class (estimated through ",
                "the random effects only): ", paste(single, collapse = ", "),
                ".")
      }
      if (length(sep) > 0) {
        message("Species whose verdicts are completely separated by the ",
                "score: ", paste(sep, collapse = ", "), ".")
      }
    }
  }
  invisible(val)
}

#' Check an output file path and its extension
#'
#' A path without extension gets `ext[1]` (with a message); a different
#' extension raises a warning.
#'
#' @param path Character scalar, output file path.
#' @param ext Character vector, accepted extensions without the dot.
#' @param arg Character scalar, argument name used in the messages.
#' @return Character scalar, the path to write to.
#' @noRd
check_file_ext <- function(path, ext, arg = "file") {
  if (!is.character(path) || length(path) != 1L || is.na(path) ||
      !nzchar(path)) {
    stop("`", arg, "` must be a single file path.", call. = FALSE)
  }
  current <- tolower(tools::file_ext(path))
  if (!nzchar(current)) {
    new_path <- paste0(path, ".", ext[1])
    message("`", arg, "` has no extension; writing to ", new_path, ".")
    return(new_path)
  }
  if (!current %in% tolower(ext)) {
    warning("`", arg, "` (", basename(path), ") does not end in .",
            paste(ext, collapse = " or ."), "; the file is written as ",
            toupper(ext[1]), " anyway.", call. = FALSE)
  }
  path
}

#' Check that a table has the required columns
#'
#' Every function reports missing columns with this one message (G5.2a).
#'
#' @param x A data frame.
#' @param cols Character vector, required column names.
#' @param arg Character scalar, argument name used in the error message.
#' @param hint Character scalar or `NULL`, appended to the message (where
#'   the table usually comes from).
#' @return `x`, invisibly.
#' @noRd
check_columns <- function(x, cols, arg, hint = NULL) {
  absent <- setdiff(cols, names(x))
  if (length(absent) > 0) {
    stop("`", arg, "` lacks the column(s): ", paste(absent, collapse = ", "),
         ".", if (!is.null(hint)) paste0(" ", hint), call. = FALSE)
  }
  invisible(x)
}

#' Check a data frame argument
#'
#' @param x Value to check.
#' @param arg Character scalar, argument name used in the error message.
#' @return `x`, invisibly.
#' @noRd
check_data_frame <- function(x, arg) {
  if (!is.data.frame(x)) {
    stop("`", arg, "` must be a data frame.", call. = FALSE)
  }
  invisible(x)
}

#' Check a model fitted with engine = "brms"
#'
#' @param fit Object to check.
#' @param arg Character scalar, argument name used in the error message.
#' @return `fit`, invisibly.
#' @noRd
check_brmsfit <- function(fit, arg = "fit") {
  if (!inherits(fit, "brmsfit")) {
    stop("`", arg, "` must be a model fitted with engine = \"brms\".",
         call. = FALSE)
  }
  invisible(fit)
}

#' Check that there are reviewed clips with a confidence score
#'
#' @param reviewed A data frame from reviewed_with_confidence().
#' @param arg Character scalar, argument name used in the error message.
#' @return `reviewed`, invisibly; stops if it has no rows.
#' @noRd
check_reviewed <- function(reviewed, arg = "validation") {
  if (nrow(reviewed) == 0) {
    stop("No reviewed clip with a confidence in `", arg, "`.", call. = FALSE)
  }
  invisible(reviewed)
}

#' Stop when weighted = TRUE has no inclusion probabilities
#'
#' @return Does not return; always stops.
#' @noRd
stop_without_inclusion_prob <- function() {
  stop("`weighted = TRUE` needs `inclusion_prob`, which no reviewed clip ",
       "has.", call. = FALSE)
}
