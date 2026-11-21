#' Read BirdNET selection tables
#'
#' Finds the BirdNET selection tables (Raven format, tab-separated) under
#' `data_dir`, reads them and stacks them in one table. The site is the name
#' of the folder that contains the tables. The `output_` prefix of BirdNET
#' output folders is removed, so `output_UEM/` becomes site `UEM`.
#'
#' The BirdNET GUI writes the Raven selection tables in one of two ways, and
#' both are read:
#'
#' - **combined**: one `BirdNET_SelectionTable.txt` per site folder, written
#'   when "Combine selection tables" is checked in the output settings
#'   (result type "Raven selection table");
#' - **one table per audio file** (the default of the GUI), named
#'   `<audio file>.BirdNET.selection.table.txt`. The tables of a folder are
#'   stacked in the order of their file names, and the `Selection` column
#'   is renumbered from 1, as in the combined table. The tables have the
#'   same columns as the combined one; in them, `Begin Time (s)` counts
#'   from the start of the audio file, like `File Offset (s)`, which is
#'   the column sheepdog uses to place a detection.
#'
#' Run BirdNET once per site, so that the tables of each site end up in
#' their own folder: per-audio tables in subfolders of a site folder would be
#' read as separate sites. A folder that holds a combined table is read from
#' it alone, and its per-audio tables are ignored, with a message. When the
#' tables of several sites share a folder, `site_pattern` takes the site
#' from the name of the audio file of each prediction (`Begin Path`)
#' instead.
#'
#' Column names are standardised to lower case without units or punctuation,
#' e.g. `Begin Time (s)` becomes `begin_time` and `File Offset (s)` becomes
#' `file_offset`.
#'
#' @param data_dir Root folder, searched recursively.
#' @param table_pattern Regular expression for the file names of combined
#'   tables.
#' @param per_audio_pattern Regular expression for the file names of
#'   per-audio tables. `NULL` reads only combined tables.
#' @param site_pattern Optional regular expression with one capture group
#'   that takes the site from the name of the audio file in `Begin Path`,
#'   instead of from the folder of the table. For example,
#'   `"^[^_]+_([^_]+)_"` reads `Campus01` from
#'   `Campinas_Campus01_20261003_074339.flac`. Use the same pattern in
#'   [list_recordings()].
#'
#' @return A tibble with one row per prediction, the column `site` first,
#'   followed by the standardised table columns. The columns `begin_time`,
#'   `end_time`, `species_code`, `confidence`, `begin_path` and `file_offset`
#'   are required.
#' @export
read_selection_tables <- function(data_dir,
                                  table_pattern = "^BirdNET_SelectionTable\\.txt$",
                                  per_audio_pattern = "\\.BirdNET\\.selection\\.table\\.txt$",
                                  site_pattern = NULL) {
  fontes <- find_selection_tables(data_dir, table_pattern, per_audio_pattern)
  if (length(fontes) == 0) {
    outras <- list.files(data_dir, pattern = "(?i)selection.?table.*\\.txt$",
                         recursive = TRUE)
    dica <- if (length(outras) > 0) {
      paste0("\n", length(outras), " other selection table(s) found, e.g. ",
             outras[1], ". Set `table_pattern` (combined tables) or ",
             "`per_audio_pattern` (one table per audio file) to match them.")
    } else ""
    stop("No selection table found in ", data_dir, " matching ",
         table_pattern,
         if (!is.null(per_audio_pattern)) paste0(" or ", per_audio_pattern),
         dica)
  }

  predicoes <- imap(fontes, function(arquivos, pasta) {
    tb <- read_site_tables(arquivos)
    if (is.null(tb)) return(NULL)
    mutate(tb, site = str_remove(basename(pasta), "^output_?"), .before = 1)
  }) |>
    list_rbind()

  if (is.null(predicoes) || nrow(predicoes) == 0) {
    stop("No prediction read - were all the tables found empty?")
  }
  check_confidence(predicoes$confidence, "Confidence")
  if (!is.null(site_pattern)) {
    predicoes$site <- site_from_name(predicoes$begin_path, site_pattern)
  }
  message(nrow(predicoes), " predictions read from ",
          n_distinct(predicoes$site), " site(s).")
  predicoes
}

# Lista as tabelas por pasta: a combinada, se houver, senao as por audio.
# Devolve uma lista nomeada pela pasta, cada elemento com os arquivos.
find_selection_tables <- function(data_dir, table_pattern, per_audio_pattern) {
  combinadas <- list.files(data_dir, pattern = table_pattern,
                           recursive = TRUE, full.names = TRUE)
  por_audio <- if (is.null(per_audio_pattern)) character() else
    list.files(data_dir, pattern = per_audio_pattern,
               recursive = TRUE, full.names = TRUE)
  por_audio <- setdiff(por_audio, combinadas)

  pastas_comb <- dirname(combinadas)
  ignoradas <- por_audio[dirname(por_audio) %in% pastas_comb]
  if (length(ignoradas) > 0) {
    message(length(ignoradas), " per-audio table(s) ignored in folder(s) ",
            "that also hold a combined table: ",
            paste(unique(dirname(ignoradas)), collapse = ", "))
  }
  por_audio <- setdiff(por_audio, ignoradas)

  fontes <- c(split(combinadas, pastas_comb),
              split(sort(por_audio), dirname(sort(por_audio))))
  if (length(fontes) == 0) return(fontes)

  message(length(combinadas), " combined table(s) and ", length(por_audio),
          " per-audio table(s) found in ", length(fontes), " folder(s):")
  iwalk(fontes, \(x, pasta) message("  - ", pasta, ": ",
                                    if (length(x) == 1) basename(x) else
                                      paste(length(x), "per-audio tables")))
  fontes[order(names(fontes))]
}

# Le as tabelas de uma pasta: uma combinada, ou varias por audio empilhadas
# com a coluna selection renumerada, como na combinada
read_site_tables <- function(arquivos) {
  vazias <- file.size(arquivos) == 0
  if (any(vazias)) {
    warning("Empty table(s) skipped: ",
            paste(arquivos[vazias], collapse = ", "))
  }
  arquivos <- arquivos[!vazias]
  if (length(arquivos) == 0) return(NULL)
  if (length(arquivos) == 1) return(read_selection_table(arquivos))

  # tudo como texto e conversao depois: uma tabela sem predicoes so tem o
  # cabecalho, e o readr adivinharia tipos diferentes para ela
  tb <- map(arquivos, read_selection_table, as_text = TRUE) |>
    list_rbind() |>
    type_convert(col_types = cols(), na = c("", "NA"))
  if ("selection" %in% names(tb)) tb$selection <- seq_len(nrow(tb))
  tb
}

# Le uma tabela de selecao e padroniza os nomes: minusculas, sem
# unidades/pontuacao, espacos -> _
read_selection_table <- function(caminho, as_text = FALSE) {
  tb <- read_tsv(caminho, show_col_types = FALSE,
                 col_types = if (as_text) cols(.default = col_character()),
                 na = c("", "NA"), progress = FALSE)

  nomes <- names(tb) |>
    str_to_lower() |>
    str_remove_all("\\((s|hz)\\)") |>
    str_trim() |>
    str_replace_all("[^a-z0-9]+", "_") |>
    str_remove("_$")
  names(tb) <- nomes

  obrigatorias <- c("begin_time", "end_time", "species_code",
                    "confidence", "begin_path", "file_offset")
  faltando <- setdiff(obrigatorias, names(tb))
  if (length(faltando) > 0) {
    stop("Table ", caminho, " lacks the columns: ",
         paste(faltando, collapse = ", "),
         "\nColumns found: ", paste(names(tb), collapse = ", "))
  }
  tb
}
