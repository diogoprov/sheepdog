# =============================================================================
# build.R
#
# Imprime sheepdog-cheatsheet.html em PDF com o Chrome, para o download do site.
# Saida: pkgdown/assets/cheatsheets/sheepdog-cheatsheet.pdf
# Rode a partir da raiz do repositorio. Precisa do Google Chrome.
# =============================================================================
chrome <- Sys.getenv("CHROME",
                     "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
fonte <- normalizePath("data-raw/cheatsheet/sheepdog-cheatsheet.html")
dir.create("pkgdown/assets/cheatsheets", recursive = TRUE, showWarnings = FALSE)
saida <- file.path(getwd(), "pkgdown/assets/cheatsheets/sheepdog-cheatsheet.pdf")
status <- system2(chrome, c("--headless", "--disable-gpu",
                            "--no-pdf-header-footer",
                            shQuote(paste0("--print-to-pdf=", saida)),
                            shQuote(paste0("file://", fonte))))
stopifnot(status == 0, file.exists(saida))

# miniaturas das paginas, para o artigo "Cheat sheets"
miniaturas <- "vignettes/articles/figures"
status <- system2("pdftoppm", c("-r", "60", "-png", shQuote(saida),
                                file.path(miniaturas, "cheatsheet-page")))
stopifnot(status == 0)
