# Folders and data of the app (Intro > Audio panel tab). The state lives in
# an environment: the Audio panel tab changes the folders, rereads the data
# and reloads the page, and the UI and server are rebuilt from it.

#' Create the state of the app
#'
#' @param manifest,clips_dir,verdicts_file,reviewer,max_freq,selection_dir,output_dir,audio_dir,site_pattern,blind,classifier
#'   As in [run_app()].
#' @param recordings A data frame of recordings, a character scalar path to
#'   its CSV, or `NULL`.
#' @return An environment holding the state (folders, data, review queue).
#' @noRd
app_state <- function(manifest = NULL, clips_dir = NULL, verdicts_file = NULL,
                      reviewer = NULL, max_freq = NULL, selection_dir = NULL,
                      output_dir = NULL, recordings = NULL, audio_dir = NULL,
                      site_pattern = NULL, blind = FALSE,
                      classifier = NULL) {
  st <- new.env(parent = emptyenv())
  st$manifest <- manifest
  st$clips_dir <- clips_dir
  st$verdicts_file <- verdicts_file
  st$reviewer <- reviewer
  st$max_freq <- max_freq
  st$classifier <- classifier
  st$selection_dir <- selection_dir
  st$output_dir <- output_dir
  st$audio_dir <- audio_dir
  st$site_pattern <- site_pattern
  st$blind <- isTRUE(blind)
  # recordings CSV given to run_app(): the audio folder updates this one
  st$recordings_arg <- if (is.character(recordings)) recordings else NULL
  st$recordings_file <- st$recordings_arg
  st$recordings <- if (is.character(recordings)) NULL else recordings
  st$given <- c(audio_dir = audio_dir, selection_dir = selection_dir,
                output_dir = output_dir)
  st$confirmed <- length(st$given) == 0
  st$review_only <- !is.null(manifest) && is.null(selection_dir) &&
    is.null(output_dir) && is.null(audio_dir)
  st$detections <- NULL
  st$clip_queue <- NULL
  st
}

#' Load the data of the state folders
#'
#' Reads the BirdNET tables, the list of recordings (written to
#' recordings.csv) and the review queue, filling default paths.
#'
#' @param st Environment from `app_state()`; modified in place.
#' @return `st`, invisibly.
#' @noRd
load_app_state <- function(st) {
  if (!is.null(st$output_dir)) {
    dir.create(st$output_dir, recursive = TRUE, showWarnings = FALSE)
    if (is.null(st$clips_dir)) st$clips_dir <- file.path(st$output_dir, "clips")
    if (is.null(st$verdicts_file)) {
      st$verdicts_file <- file.path(st$output_dir, "verdicts.csv")
    }
    manifest_path <- file.path(st$output_dir, "clip_manifest.csv")
    if (is.null(st$manifest) && file.exists(manifest_path)) {
      st$manifest <- manifest_path
    }
  }
  if (is.null(st$verdicts_file) && is.character(st$manifest)) {
    st$verdicts_file <- file.path(dirname(st$manifest), "verdicts.csv")
  }

  st$detections <- if (!is.null(st$selection_dir)) {
    read_selection_tables(st$selection_dir, site_pattern = st$site_pattern)
  }

  if (!is.null(st$audio_dir)) {
    target <- if (!is.null(st$recordings_arg)) st$recordings_arg else
      if (!is.null(st$output_dir)) file.path(st$output_dir, "recordings.csv")
    st$recordings <- app_recordings(st$audio_dir, target, st$site_pattern)
    st$recordings_file <- target
  } else if (!is.null(st$recordings_file) && file.exists(st$recordings_file)) {
    st$recordings <- read_csv(st$recordings_file, show_col_types = FALSE)
  }

  st$clip_queue <- NULL
  if (!is.null(st$manifest) && !is.null(st$clips_dir)) {
    st$clip_queue <- if (st$review_only) {
      review_queue(st$manifest, st$clips_dir, st$reviewer, blind = st$blind)
    } else {
      # a manifest without cut clips does not stop the app from opening:
      # the clips can be drawn and cut again
      tryCatch(review_queue(st$manifest, st$clips_dir, st$reviewer,
                            blind = st$blind),
               error = function(e) {
                 warning(conditionMessage(e), " Opening the app without ",
                         "clips to review; draw and cut them again in the ",
                         "Sampling tab, with \"Replace\" ticked.",
                         call. = FALSE)
                 NULL
               })
    }
  }
  invisible(st)
}

#' List the recordings of the audio folder
#'
#' Files placed directly in the folder take the folder name as site.
#'
#' @param audio_dir Character scalar, folder of the recordings.
#' @param file Character scalar or `NULL`, CSV where the list is written.
#' @param site_pattern Character scalar or `NULL`, regular expression with
#'   one capture group for the site.
#' @return A data frame from [list_recordings()].
#' @noRd
app_recordings <- function(audio_dir, file = NULL, site_pattern = NULL) {
  if (!is.null(site_pattern)) {
    return(list_recordings(audio_dir, site_pattern = site_pattern,
                           file = file))
  }
  tryCatch(list_recordings(audio_dir, file = file), error = function(e) {
    if (!grepl("directly in `audio_dir`", conditionMessage(e))) stop(e)
    list_recordings(audio_dir, site = basename(sub("/+$", "", audio_dir)),
                    file = file)
  })
}

#' Test whether the Sampling and Export tabs can open
#'
#' They need the BirdNET tables and the folder of the round.
#'
#' @param st Environment from `app_state()`.
#' @return Logical scalar.
#' @noRd
app_ready <- function(st) !is.null(st$detections) && !is.null(st$output_dir)

#' Placeholder of a tab that needs the folders
#'
#' @return A 'shiny' tag.
#' @noRd
needs_folders_ui <- function() {
  shiny::div(
    class = "alert alert-info", style = "margin-top: 20px;",
    shiny::p("Choose the BirdNET results and the validation folder in",
             shiny::strong("Intro > Audio panel"), "to use this tab."))
}

#' Choose a folder with a system dialog
#'
#' Uses RStudio, Windows, macOS or Linux (tcltk). The system calls live in
#' their own functions (`dir_dialog_*()`), which the tests replace.
#'
#' @param default Character scalar or `NULL`, folder where the dialog
#'   starts; the home folder when missing or nonexistent.
#' @param caption Character scalar, title of the dialog.
#' @return Character scalar, the chosen folder without a trailing slash, or
#'   `NULL` when no dialog can open or nothing was chosen.
#' @noRd
choose_dir <- function(default = NULL, caption = "Choose a folder") {
  start_dir <- if (!is.null(default) && nzchar(default) &&
                dir.exists(path.expand(default))) {
    path.expand(default)
  } else {
    path.expand("~")
  }
  is_empty <- function(d) is.null(d) || length(d) == 0 || is.na(d[1]) ||
    !nzchar(d[1])
  d <- if (dir_dialog_rstudio_available()) {
    dir_dialog_rstudio(caption, start_dir)
  } else {
    switch(dir_dialog_os(),
           Windows = dir_dialog_windows(start_dir, caption),
           Darwin = dir_dialog_macos(start_dir, caption),
           Linux = if (dir_dialog_tcltk_available()) {
             dir_dialog_tcltk(start_dir, caption)
           },
           NULL)
  }
  if (is_empty(d)) NULL else sub("/+$", "", d[1])
}

#' Name of the operating system
#'
#' @return Character scalar, e.g. `"Darwin"`.
#' @noRd
dir_dialog_os <- function() Sys.info()[["sysname"]]

#' Test whether the RStudio folder dialog is available
#'
#' @return Logical scalar.
#' @noRd
dir_dialog_rstudio_available <- function() {
  requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()
}

#' Folder dialog of RStudio
#'
#' @param caption Character scalar, title of the dialog.
#' @param start_dir Character scalar, folder where the dialog starts.
#' @return Character scalar path, or `NULL` on error.
#' @noRd
dir_dialog_rstudio <- function(caption, start_dir) {
  tryCatch(rstudioapi::selectDirectory(caption, path = start_dir),
           error = function(e) NULL)
}

#' Folder dialog of Windows
#'
#' @param start_dir Character scalar, folder where the dialog starts.
#' @param caption Character scalar, title of the dialog.
#' @return Character scalar path, or `NA` when cancelled.
#' @noRd
dir_dialog_windows <- function(start_dir, caption) {
  # utils::choose.dir() only exists on Windows
  choose <- get("choose.dir", envir = asNamespace("utils"))
  choose(start_dir, caption)
}

#' Folder dialog of macOS (osascript)
#'
#' @param start_dir Character scalar, folder where the dialog starts.
#' @param caption Character scalar, title of the dialog.
#' @return Character vector with the chosen path, empty when cancelled.
#' @noRd
dir_dialog_macos <- function(start_dir, caption) {
  cmd <- sprintf(paste0("POSIX path of (choose folder with prompt \"%s\" ",
                        "default location POSIX file \"%s\")"),
                 gsub("\"", "", caption), gsub("\"", "", start_dir))
  suppressWarnings(tryCatch(
    system2("osascript", c("-e", shQuote(cmd)), stdout = TRUE,
            stderr = FALSE),
    error = function(e) character()))
}

#' Test whether the tcltk folder dialog is available
#'
#' tcltk needs a display (DISPLAY); on a headless server the dialog does
#' not open and the path is typed in the field.
#'
#' @return Logical scalar.
#' @noRd
dir_dialog_tcltk_available <- function() {
  isTRUE(capabilities("tcltk")) && nzchar(Sys.getenv("DISPLAY")) &&
    requireNamespace("tcltk", quietly = TRUE)
}

#' Folder dialog of tcltk
#'
#' @param start_dir Character scalar, folder where the dialog starts.
#' @param caption Character scalar, title of the dialog.
#' @return Character scalar path, or `NULL` on error.
#' @noRd
dir_dialog_tcltk <- function(start_dir, caption) {
  tryCatch(tcltk::tk_choose.dir(start_dir, caption), error = function(e) NULL)
}

# ---------------------------------------------------------------------------
# Audio panel tab

#' Folder fields of the Audio panel and their labels
#' @noRd
setup_fields <- c(audio_dir = "Audio folder",
                  selection_dir = "BirdNET results",
                  output_dir = "Validation folder")

#' UI of the Audio panel tab
#'
#' @param id Character scalar, module id.
#' @param st Environment from `app_state()`.
#' @return A 'shiny' tag list.
#' @noRd
setup_ui <- function(id, st) {
  ns <- shiny::NS(id)
  field <- function(name, help_text) {
    value <- st[[name]]
    shiny::tagList(
      shiny::tags$label(setup_fields[[name]], `for` = ns(name)),
      shiny::div(
        style = "display: flex; gap: 8px;",
        shiny::div(style = "flex: 1;",
                   shiny::textInput(ns(name), NULL,
                                    if (is.null(value)) "" else value,
                                    width = "100%")),
        shiny::div(shiny::actionButton(ns(paste0(name, "_browse")),
                                       "Browse..."))),
      hint(help_text))
  }
  shiny::tagList(
    shiny::fluidRow(
      shiny::column(
        7,
        shiny::h4("Folders"),
        field("audio_dir", paste(
          "Folder of the recordings, subfolders included. Every recording",
          "is listed (site and file path) in recordings.csv, in the",
          "validation folder or the CSV given to run_app().")),
        field("selection_dir", paste(
          "Folder of the BirdNET selection tables (selection_dir).")),
        field("output_dir", paste(
          "Where the clips, the manifest, the verdicts and the export are",
          "written (output_dir). Created if missing.")),
        shiny::textInput(ns("site_pattern"), "Site from the file name",
                         if (is.null(st$site_pattern)) "" else
                           st$site_pattern, width = "100%"),
        hint(paste(
          "Optional. When the recordings or the tables of several sites",
          "share a folder: a regular expression with the site in",
          "parentheses, e.g. <code>^[^_]+_([^_]+)_</code> reads Campus01",
          "from Campinas_Campus01_20261003_074339.flac. Empty: the site is",
          "the folder name.")),
        shiny::actionButton(ns("apply"), "Apply and reload",
                            class = "btn-primary")),
      shiny::column(5, shiny::h4("Loaded"), shiny::uiOutput(ns("status")))),
    shiny::hr(),
    shiny::h4("Recordings per site and night"),
    shiny::selectizeInput(
      ns("species"), "Species",
      sort(unique(as.character(st$detections$species_code))),
      multiple = TRUE, width = "100%",
      options = list(placeholder = "All species")),
    hint(paste(
      "Predictions of these species only, at any score. Leave empty for",
      "all species.")),
    hint(paste(
      "Square size: number of recordings that night. Colour: share of the",
      "hours recorded that night with at least one prediction of the chosen",
      "species. Recordings before noon belong to the night before. Hover a",
      "square for the number of predictions.")),
    shiny::uiOutput(ns("summary")),
    summary_tooltip())
}

#' Tooltip of the summary squares
#'
#' Shows the `data-tip` attribute on hover; the SVG `<title>` does not show
#' in the RStudio Viewer.
#'
#' @return A 'shiny' tag list with a `div` and a script.
#' @noRd
summary_tooltip <- function() {
  shiny::tagList(
    shiny::tags$div(id = "sheepdog-tip", style = paste(
      "position: fixed; display: none; z-index: 2000; pointer-events: none;",
      "background: #222; color: #fff; padding: 6px 9px; border-radius: 5px;",
      "font-size: 12px; line-height: 1.4; white-space: pre-line;",
      "max-width: 320px;")),
    shiny::tags$script(shiny::HTML(
      "(function() {
         function tip() { return document.getElementById('sheepdog-tip'); }
         document.addEventListener('mousemove', function(e) {
           var t = tip(); if (!t) return;
           var el = e.target.closest ? e.target.closest('[data-tip]') : null;
           if (!el) { t.style.display = 'none'; return; }
           t.textContent = el.getAttribute('data-tip');
           t.style.display = 'block';
           var x = Math.min(e.clientX + 14, window.innerWidth - t.offsetWidth - 8);
           var y = Math.min(e.clientY + 14, window.innerHeight - t.offsetHeight - 8);
           t.style.left = x + 'px'; t.style.top = y + 'px';
         });
       })();")))
}

#' Server of the Audio panel tab
#'
#' @param id Character scalar, module id.
#' @param st Environment from `app_state()`; updated when the folders are
#'   applied.
#' @param root The root 'shiny' session (or an object with a `reload()`
#'   method), reloaded after the folders are applied.
#' @param on_apply Function with no arguments, called after the folders are
#'   applied and before the reload.
#' @return Called for its side effects.
#' @noRd
setup_server <- function(id, st, root, on_apply = function() NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    captions <- c(audio_dir = "Folder of the recordings",
                  selection_dir = "Folder of the BirdNET selection tables",
                  output_dir = "Validation folder")
    lapply(names(setup_fields), function(name) {
      shiny::observeEvent(input[[paste0(name, "_browse")]], {
        d <- choose_dir(input[[name]], captions[[name]])
        if (is.null(d)) {
          shiny::showNotification(
            "No folder was chosen. You can also type the path.",
            type = "message")
        } else {
          shiny::updateTextInput(session, name, value = d)
        }
      })
    })

    shiny::observeEvent(input$apply, {
      new_vals <- lapply(names(setup_fields), function(n) {
        v <- trimws(if (is.null(input[[n]])) "" else input[[n]])
        if (nzchar(v)) sub("/+$", "", path.expand(v)) else NULL
      })
      names(new_vals) <- names(setup_fields)
      pattern <- trimws(if (is.null(input$site_pattern)) "" else
        input$site_pattern)
      # list(NULL) keeps the NULL (new_vals$x <- NULL would drop the element)
      new_vals["site_pattern"] <- list(if (nzchar(pattern)) pattern else NULL)
      for (n in c("audio_dir", "selection_dir")) {
        if (!is.null(new_vals[[n]]) && !dir.exists(new_vals[[n]])) {
          shiny::showNotification(
            paste0(setup_fields[[n]], ": ", new_vals[[n]],
                   " does not exist."),
            type = "error", duration = NULL)
          return()
        }
      }
      keys <- c(names(setup_fields), "site_pattern", "clips_dir",
                  "verdicts_file", "manifest", "recordings_file",
                  "recordings")
      before <- mget(keys, envir = st)
      if (!identical(before$output_dir, new_vals$output_dir)) {
        st$clips_dir <- NULL
        st$verdicts_file <- NULL
        st$manifest <- NULL
      }
      for (n in names(new_vals)) assign(n, new_vals[[n]], envir = st)
      ok <- tryCatch({
        withCallingHandlers(
          load_app_state(st),
          warning = function(w) {
            shiny::showNotification(conditionMessage(w), type = "warning",
                                    duration = NULL)
            invokeRestart("muffleWarning")
          },
          message = function(m) invokeRestart("muffleMessage"))
        TRUE
      }, error = function(e) {
        shiny::showNotification(paste("Error:", conditionMessage(e)),
                                type = "error", duration = NULL)
        FALSE
      })
      if (!ok) {
        for (n in keys) assign(n, before[[n]], envir = st)
        try(suppressWarnings(suppressMessages(load_app_state(st))),
            silent = TRUE)
        return()
      }
      st$confirmed <- TRUE
      on_apply()
      root$reload()
    })

    output$status <- shiny::renderUI({
      item <- function(label, value) shiny::tags$li(shiny::strong(label),
                                                    value)
      det <- st$detections
      rec <- st$recordings
      shiny::tags$ul(
        item("BirdNET predictions: ", if (is.null(det)) "none" else
          paste0(format(nrow(det), big.mark = ","), " from ",
                 n_distinct(det$site), " site folder(s)")),
        item("Recordings: ", if (is.null(rec)) "none (choose the audio folder)"
              else paste0(nrow(rec), " at ", n_distinct(rec$site), " site(s)",
                          if (!is.null(st$recordings_file))
                            paste0(", in ", st$recordings_file))),
        item("Clip manifest: ", if (is.character(st$manifest))
          st$manifest else if (is.null(st$manifest)) "none yet" else
            "a table given to run_app()"),
        item("Clips to review: ", if (is.null(st$clip_queue)) "0" else
          nrow(st$clip_queue)))
    })

    output$summary <- shiny::renderUI({
      sp <- input$species
      tab <- recording_summary(st$recordings, st$detections, species = sp)
      if (is.null(tab)) {
        return(shiny::p("Choose the audio folder or the BirdNET results to",
                        "see the recordings."))
      }
      shiny::tagList(
        if (isTRUE(attr(tab, "from_detections"))) {
          hint(paste("Without the audio folder, only the recordings with",
                     "predictions are counted."))
        },
        shiny::div(style = "overflow-x: auto;",
                   shiny::HTML(summary_svg(tab, species = sp))))
    })
  })
}

#' Ask whether the folders given to run_app() still hold
#'
#' @param st Environment from `app_state()`.
#' @param input,session The 'shiny' input and session of the app.
#' @return `NULL`, invisibly; shows a modal dialog and sets `st$confirmed`.
#' @noRd
confirm_folders <- function(st, input, session) {
  if (isTRUE(st$confirmed) || length(st$given) == 0) return(invisible())
  items <- lapply(names(st$given), function(n) {
    # long paths wrap instead of overflowing the dialog
    shiny::tags$li(shiny::strong(paste0(setup_fields[[n]], ": ")),
                   shiny::code(st$given[[n]],
                               style = paste("white-space: normal;",
                                             "word-break: break-all;")))
  })
  shiny::showModal(shiny::modalDialog(
    title = "Are these folders still right?",
    shiny::p("run_app() was given:"),
    shiny::tags$ul(items),
    shiny::p("Keep them, or change them in Intro > Audio panel."),
    footer = shiny::tagList(
      shiny::actionButton("folders_change", "Change them"),
      shiny::actionButton("folders_keep", "Keep them",
                          class = "btn-primary"))))
  shiny::observeEvent(input$folders_keep, {
    st$confirmed <- TRUE
    shiny::removeModal()
  })
  shiny::observeEvent(input$folders_change, {
    st$confirmed <- TRUE
    shiny::removeModal()
    shiny::updateNavbarPage(session, "tabs", "Intro")
    shiny::updateNavlistPanel(session, "intro_nav", "Audio panel")
  })
  invisible()
}

# ---------------------------------------------------------------------------
# Summary of the recordings: site x night

#' Summarise the recordings per site and night
#'
#' Before `dawn_hour`, a recording belongs to the night before, as in
#' score_detections(). Without the list of recordings, the files of all
#' predictions are used.
#'
#' @param recordings A data frame with columns `site` and `source_audio`,
#'   or `NULL`.
#' @param detections A data frame of BirdNET predictions (columns `site`,
#'   `begin_path`, `species_code`), or `NULL`.
#' @param species Character vector or `NULL`; limits only the prediction
#'   counts, not the recordings.
#' @param dawn_hour Numeric scalar, hour that splits the nights.
#' @return A tibble with one row per site x night: `n_recordings`,
#'   `hours_recorded`, `n_detections`, `hours_with_detections` and
#'   `prop_hours`, with attribute `from_detections`; or `NULL` when there is
#'   nothing to summarise.
#' @noRd
recording_summary <- function(recordings = NULL, detections = NULL,
                              species = NULL, dawn_hour = 12) {
  from_det <- is.null(recordings)
  if (from_det) {
    if (is.null(detections) || nrow(detections) == 0) return(NULL)
    recordings <- distinct(tibble(
      site = as.character(detections$site),
      source_audio = remap_path(detections$begin_path)))
  }
  if (!is.null(detections) && length(species) > 0) {
    detections <- detections[as.character(detections$species_code) %in%
                               species, ]
  }
  rec <- tibble(site = as.character(recordings$site),
                file = basename(remap_path(recordings$source_audio)))
  rec <- bind_cols(rec, parse_date_hour(rec$file)) |>
    filter(!is.na(recording_date)) |>
    distinct(file, .keep_all = TRUE) |>
    mutate(night = night_of(recording_date, recording_hour, dawn_hour))
  if (nrow(rec) == 0) return(NULL)
  nights <- rec |>
    group_by(site, night) |>
    summarise(n_recordings = n(),
              hours_recorded = n_distinct(recording_date, recording_hour),
              .groups = "drop")
  if (!is.null(detections) && nrow(detections) > 0) {
    det <- count(tibble(file = basename(remap_path(detections$begin_path))),
                 file, name = "n_det")
    hours <- inner_join(rec, det, by = "file") |>
      group_by(site, night) |>
      summarise(n_detections = sum(n_det),
                hours_with_detections = n_distinct(recording_date,
                                                   recording_hour),
                .groups = "drop")
    nights <- left_join(nights, hours, by = c("site", "night")) |>
      mutate(n_detections = replace_na(n_detections, 0L),
             hours_with_detections = replace_na(hours_with_detections, 0L))
  } else {
    nights$n_detections <- NA_integer_
    nights$hours_with_detections <- NA_integer_
  }
  nights$prop_hours <- nights$hours_with_detections / nights$hours_recorded
  attr(nights, "from_detections") <- from_det
  nights
}

#' Colour of a proportion on a sequential scale
#'
#' @param p Numeric vector in \[0, 1\]; `NA` gives grey.
#' @return Character vector of hex colours, same length as `p`.
#' @noRd
summary_colour <- function(p) {
  pal <- c("#f4f1d0", "#c9e4a4", "#7cc49d", "#2e8f9e", "#22507e")
  rgb <- t(vapply(pal, function(h) strtoi(substring(h, c(2, 4, 6),
                                                       c(3, 5, 7)), 16L),
                  numeric(3)))
  vapply(p, function(x) {
    if (is.na(x)) return("#d9d9d9")
    pos <- 1 + min(max(x, 0), 1) * (length(pal) - 1)
    i <- min(floor(pos), length(pal) - 1)
    f <- pos - i
    v <- round(rgb[i, ] * (1 - f) + rgb[i + 1, ] * f)
    sprintf("#%02x%02x%02x", v[1], v[2], v[3])
  }, character(1))
}

#' Draw the site x night summary as SVG
#'
#' @param tab A tibble from `recording_summary()`.
#' @param species Character vector or `NULL`, the chosen species, named in
#'   the tooltips.
#' @return Character scalar with the SVG markup.
#' @noRd
summary_svg <- function(tab, species = NULL) {
  which_sp <- if (length(species) == 0) "any species" else
    if (length(species) == 1) species else
      paste(length(species), "species")
  esc <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x <- gsub("\"", "&quot;", x, fixed = TRUE)
    gsub("\n", "&#10;", x, fixed = TRUE)
  }
  sites <- sort(unique(tab$site))
  nights <- sort(unique(tab$night))
  cell <- 34
  label_len <- max(nchar(sites))
  left <- 96
  top <- 20 + min(label_len, 30) * 5.2
  width <- max(left + length(sites) * cell + 20, 380)
  grid_height <- length(nights) * cell
  height <- top + grid_height + 120
  max_n <- max(tab$n_recordings)
  side <- function(n) 8 + (cell - 12) * sqrt(n / max_n)
  fmt_night <- function(d) paste(substr(d, 1, 4), substr(d, 5, 6),
                               substr(d, 7, 8), sep = "-")
  s <- sprintf(paste0('<svg xmlns="http://www.w3.org/2000/svg" width="%d" ',
                      'height="%d" font-family="sans-serif" font-size="12">'),
               round(width), round(height))
  for (i in seq_along(sites)) {
    x <- left + (i - 0.5) * cell
    s <- paste0(s, sprintf(paste0('<text transform="translate(%.1f %.1f) ',
                                  'rotate(-50)" fill="#333">%s</text>'),
                           x + 4, top - 6, esc(sites[i])))
  }
  for (j in seq_along(nights)) {
    y <- top + (j - 0.5) * cell
    s <- paste0(s, sprintf('<text x="%d" y="%.1f" text-anchor="end" fill="#333">%s</text>',
                           left - 8, y + 4, fmt_night(nights[j])))
  }
  for (k in seq_len(nrow(tab))) {
    r <- tab[k, ]
    i <- match(r$site, sites)
    j <- match(r$night, nights)
    cx <- left + (i - 0.5) * cell
    cy <- top + (j - 0.5) * cell
    l <- side(r$n_recordings)
    tip <- paste0(
      r$site, ", night of ", fmt_night(r$night), "\n",
      r$n_recordings, " recording(s), ", r$hours_recorded, " hour(s)",
      if (!is.na(r$n_detections)) paste0(
        "\n", r$hours_with_detections, " of ", r$hours_recorded,
        " hour(s) with predictions (", round(100 * r$prop_hours), "%)",
        "\n", format(r$n_detections, big.mark = ","),
        " prediction(s) of ", which_sp, ", any score"))
    s <- paste0(s, sprintf(
      paste0('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="3" ',
             'fill="%s" stroke="#555" stroke-width="0.6" data-tip="%s" ',
             'style="cursor: pointer;"/>'),
      cx - l / 2, cy - l / 2, l, l, summary_colour(r$prop_hours), esc(tip)))
  }
  # legends: size and colour
  y0 <- top + grid_height + 28
  s <- paste0(s, sprintf('<text x="%d" y="%.1f" fill="#333">Recordings</text>',
                         left - 80, y0 + 4))
  legend_ns <- unique(c(1, round(max_n / 2), max_n))
  x <- left
  for (n in legend_ns) {
    l <- side(n)
    s <- paste0(s, sprintf(paste0('<rect x="%.1f" y="%.1f" width="%.1f" ',
                                  'height="%.1f" rx="3" fill="#ffffff" ',
                                  'stroke="#555" stroke-width="0.6"/>',
                                  '<text x="%.1f" y="%.1f" fill="#333">%d</text>'),
                           x, y0 - l / 2, l, l, x + l + 4, y0 + 4, n))
    x <- x + l + 30
  }
  y1 <- y0 + cell / 2 + 44
  s <- paste0(s, sprintf('<text x="%d" y="%.1f" fill="#333">Hours with predictions</text>',
                         left - 80, y1 - 14))
  stops <- vapply(0:4, function(q) sprintf(
    '<stop offset="%d%%" stop-color="%s"/>', q * 25, summary_colour(q / 4)),
    character(1))
  s <- paste0(s, '<defs><linearGradient id="sheepdog-prop">',
              paste(stops, collapse = ""), '</linearGradient></defs>',
              sprintf(paste0('<rect x="%d" y="%.1f" width="160" height="10" ',
                             'fill="url(#sheepdog-prop)" stroke="#555" ',
                             'stroke-width="0.6"/>',
                             '<text x="%d" y="%.1f" fill="#333">0%%</text>',
                             '<text x="%d" y="%.1f" text-anchor="end" ',
                             'fill="#333">100%%</text>'),
                      left, y1 - 4, left, y1 + 20, left + 160, y1 + 20),
              '</svg>')
  s
}
