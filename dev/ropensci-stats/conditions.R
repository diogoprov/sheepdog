# Inventory of the conditions raised in R/ (stop, warning, message) and of
# whether a test matches them (standards G5.2, G5.2a, G5.2b).
# Run from the package root: Rscript dev/ropensci-stats/conditions.R
# The first string literal of each call is taken as its key; a condition
# counts as tested when that key (or its first 25 characters) appears in a
# file under tests/testthat.

arquivos <- list.files("R", pattern = "[.]R$", full.names = TRUE)
conds <- do.call(rbind, lapply(arquivos, function(f) {
  pd <- utils::getParseData(parse(f, keep.source = TRUE))
  ids <- pd$parent[pd$token == "SYMBOL_FUNCTION_CALL" &
                     pd$text %in% c("stop", "warning", "message")]
  do.call(rbind, lapply(ids, function(id) {
    call_id <- pd$parent[pd$id == id]
    fn <- pd$text[pd$parent == id & pd$token == "SYMBOL_FUNCTION_CALL"]
    cl <- pd[pd$id == call_id, ]
    dentro <- (pd$line1 > cl$line1 | (pd$line1 == cl$line1 & pd$col1 >= cl$col1)) &
      (pd$line2 < cl$line2 | (pd$line2 == cl$line2 & pd$col2 <= cl$col2))
    desc <- pd[dentro, ]
    lit <- desc$text[desc$token == "STR_CONST"]
    linha <- pd$line1[pd$id == call_id]
    if (length(lit) == 0) return(NULL)
    txt <- vapply(lit, function(s) eval(parse(text = s)), "")
    out <- data.frame(file = basename(f), line = linha, fn = fn,
                      key = txt[1], text = paste(txt, collapse = ""))
    out$pieces <- list(txt)
    out
  }))
}))
conds <- conds[!duplicated(conds[c("file", "line", "text")]), ]
# String literals of the tests (patterns given to expect_error() and the
# like, or to grepl() on captured conditions), tried as regular
# expressions, then as fixed strings, against the text of each condition
# (its string literals joined)
lits <- unlist(lapply(list.files("tests/testthat", pattern = "[.]R$",
                                 full.names = TRUE), function(f) {
  pd <- utils::getParseData(parse(f, keep.source = TRUE))
  fns <- c("expect_error", "expect_warning", "expect_message",
           "expect_condition", "expect_match", "grepl", "grep")
  str <- pd[pd$token == "STR_CONST", ]
  pai <- function(id) pd$parent[match(id, pd$id)]
  chamada <- pai(pai(str$id))
  nome <- vapply(chamada, function(cid) {
    filho <- pd$id[pd$parent == cid & pd$token == "expr"][1]
    f <- pd$text[pd$parent == filho & pd$token == "SYMBOL_FUNCTION_CALL"]
    if (length(f)) f[1] else ""
  }, "")
  x <- str$text[nome %in% fns]
  vapply(x, function(s) eval(parse(text = s)), "")
}))
lits <- unique(lits[nchar(lits) >= 4])
snaps <- paste(unlist(lapply(list.files("tests/testthat/_snaps",
                                        full.names = TRUE, recursive = TRUE),
                             readLines)), collapse = "\n")
# A condition counts as tested when a test pattern matches its text, or
# when a pattern (regular expression escapes removed) and one of the
# literal pieces of the message contain each other: messages are built
# from literals and values, and the patterns often include the values.
lits_fixos <- gsub("\\\\(.)", "\\1", lits)
casa <- function(txt, pecas) {
  pecas <- trimws(pecas[nchar(trimws(pecas)) >= 10])
  any(vapply(lits, function(p) {
    tryCatch(grepl(p, txt, perl = TRUE), error = function(e) FALSE) ||
      grepl(p, txt, fixed = TRUE)
  }, logical(1))) ||
    any(vapply(pecas, function(pc) {
      any(grepl(pc, lits_fixos, fixed = TRUE)) ||
        any(nchar(lits_fixos) >= 12 &
              vapply(lits_fixos, grepl, logical(1), x = pc, fixed = TRUE))
    }, logical(1))) ||
    grepl(substr(txt, 1, 30), snaps, fixed = TRUE)
}
conds$text <- gsub('\\\\"', '"', conds$text)
conds$tested <- mapply(casa, conds$text, conds$pieces)
dup <- conds$text[duplicated(conds$text) & nchar(conds$text) > 15]
cat("Conditions:", nrow(conds), "\n")
print(tapply(conds$tested, conds$fn, mean))
cat("Overall tested:", round(mean(conds$tested), 2), "\n")
cat("Duplicated keys:", length(unique(dup)), "\n")
if (length(dup)) print(conds[conds$text %in% dup, c("file", "line", "text")], row.names = FALSE)
if (identical(Sys.getenv("SHOW_UNTESTED"), "true")) {
  print(conds[!conds$tested, c("file", "line", "fn", "key")], right = FALSE)
}
