# Pastas e dados do app (aba Intro > Audio panel). O estado fica num
# ambiente: a aba Audio panel troca as pastas, relê os dados e recarrega a
# pagina, e a interface e o servidor sao montados de novo a partir dele.

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
  # CSV das gravacoes dado a run_app(): e ele que a pasta de audio atualiza
  st$recordings_arg <- if (is.character(recordings)) recordings else NULL
  st$recordings_file <- st$recordings_arg
  st$recordings <- if (is.character(recordings)) NULL else recordings
  st$given <- c(audio_dir = audio_dir, selection_dir = selection_dir,
                output_dir = output_dir)
  st$confirmed <- length(st$given) == 0
  st$review_only <- !is.null(manifest) && is.null(selection_dir) &&
    is.null(output_dir) && is.null(audio_dir)
  st$detections <- NULL
  st$fila <- NULL
  st
}

# Le os dados das pastas do estado: tabelas do BirdNET, lista de gravacoes
# (escrita em recordings.csv) e a fila de revisao
load_app_state <- function(st) {
  if (!is.null(st$output_dir)) {
    dir.create(st$output_dir, recursive = TRUE, showWarnings = FALSE)
    if (is.null(st$clips_dir)) st$clips_dir <- file.path(st$output_dir, "clips")
    if (is.null(st$verdicts_file)) {
      st$verdicts_file <- file.path(st$output_dir, "verdicts.csv")
    }
    caminho <- file.path(st$output_dir, "clip_manifest.csv")
    if (is.null(st$manifest) && file.exists(caminho)) st$manifest <- caminho
  }
  if (is.null(st$verdicts_file) && is.character(st$manifest)) {
    st$verdicts_file <- file.path(dirname(st$manifest), "verdicts.csv")
  }

  st$detections <- if (!is.null(st$selection_dir)) {
    read_selection_tables(st$selection_dir, site_pattern = st$site_pattern)
  }

  if (!is.null(st$audio_dir)) {
    alvo <- if (!is.null(st$recordings_arg)) st$recordings_arg else
      if (!is.null(st$output_dir)) file.path(st$output_dir, "recordings.csv")
    st$recordings <- app_recordings(st$audio_dir, alvo, st$site_pattern)
    st$recordings_file <- alvo
  } else if (!is.null(st$recordings_file) && file.exists(st$recordings_file)) {
    st$recordings <- read_csv(st$recordings_file, show_col_types = FALSE)
  }

  st$fila <- NULL
  if (!is.null(st$manifest) && !is.null(st$clips_dir)) {
    st$fila <- if (st$review_only) {
      review_queue(st$manifest, st$clips_dir, st$reviewer, blind = st$blind)
    } else {
      # um manifesto sem clipes cortados nao impede o app de abrir: da para
      # sortear e cortar de novo
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

# Lista as gravacoes da pasta de audio; arquivos soltos na pasta ficam com o
# nome da pasta como local
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

# As abas de sorteio e exportacao precisam das tabelas e da pasta da rodada
app_ready <- function(st) !is.null(st$detections) && !is.null(st$output_dir)

needs_folders_ui <- function() {
  shiny::div(
    class = "alert alert-info", style = "margin-top: 20px;",
    shiny::p("Choose the BirdNET results and the validation folder in",
             shiny::strong("Intro > Audio panel"), "to use this tab."))
}

# Janela do sistema para escolher uma pasta: RStudio, Windows, macOS ou
# Linux (tcltk). NULL quando nao ha como abrir a janela ou nada foi escolhido.
# As chamadas ao sistema ficam em funcoes proprias (dir_dialog_*), que os
# testes substituem.
choose_dir <- function(default = NULL, caption = "Choose a folder") {
  inicio <- if (!is.null(default) && nzchar(default) &&
                dir.exists(path.expand(default))) {
    path.expand(default)
  } else {
    path.expand("~")
  }
  vazio <- function(d) is.null(d) || length(d) == 0 || is.na(d[1]) ||
    !nzchar(d[1])
  d <- if (dir_dialog_rstudio_available()) {
    dir_dialog_rstudio(caption, inicio)
  } else {
    switch(dir_dialog_os(),
           Windows = dir_dialog_windows(inicio, caption),
           Darwin = dir_dialog_macos(inicio, caption),
           Linux = if (dir_dialog_tcltk_available()) {
             dir_dialog_tcltk(inicio, caption)
           },
           NULL)
  }
  if (vazio(d)) NULL else sub("/+$", "", d[1])
}

dir_dialog_os <- function() Sys.info()[["sysname"]]

dir_dialog_rstudio_available <- function() {
  requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()
}

dir_dialog_rstudio <- function(caption, inicio) {
  tryCatch(rstudioapi::selectDirectory(caption, path = inicio),
           error = function(e) NULL)
}

dir_dialog_windows <- function(inicio, caption) {
  # utils::choose.dir() so existe no Windows
  escolher <- get("choose.dir", envir = asNamespace("utils"))
  escolher(inicio, caption)
}

dir_dialog_macos <- function(inicio, caption) {
  cmd <- sprintf(paste0("POSIX path of (choose folder with prompt \"%s\" ",
                        "default location POSIX file \"%s\")"),
                 gsub("\"", "", caption), gsub("\"", "", inicio))
  suppressWarnings(tryCatch(
    system2("osascript", c("-e", shQuote(cmd)), stdout = TRUE,
            stderr = FALSE),
    error = function(e) character()))
}

# O tcltk precisa de uma tela (DISPLAY); num servidor sem tela a janela nao
# abre e o caminho e digitado no campo
dir_dialog_tcltk_available <- function() {
  isTRUE(capabilities("tcltk")) && nzchar(Sys.getenv("DISPLAY")) &&
    requireNamespace("tcltk", quietly = TRUE)
}

dir_dialog_tcltk <- function(inicio, caption) {
  tryCatch(tcltk::tk_choose.dir(inicio, caption), error = function(e) NULL)
}

# ---------------------------------------------------------------------------
# Aba Audio panel

setup_fields <- c(audio_dir = "Audio folder",
                  selection_dir = "BirdNET results",
                  output_dir = "Validation folder")

setup_ui <- function(id, st) {
  ns <- shiny::NS(id)
  campo <- function(nome, ajuda) {
    valor <- st[[nome]]
    shiny::tagList(
      shiny::tags$label(setup_fields[[nome]], `for` = ns(nome)),
      shiny::div(
        style = "display: flex; gap: 8px;",
        shiny::div(style = "flex: 1;",
                   shiny::textInput(ns(nome), NULL,
                                    if (is.null(valor)) "" else valor,
                                    width = "100%")),
        shiny::div(shiny::actionButton(ns(paste0(nome, "_browse")),
                                       "Browse..."))),
      hint(ajuda))
  }
  shiny::tagList(
    shiny::fluidRow(
      shiny::column(
        7,
        shiny::h4("Folders"),
        campo("audio_dir", paste(
          "Folder of the recordings, subfolders included. Every recording",
          "is listed (site and file path) in recordings.csv, in the",
          "validation folder or the CSV given to run_app().")),
        campo("selection_dir", paste(
          "Folder of the BirdNET selection tables (selection_dir).")),
        campo("output_dir", paste(
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

# Dica ao passar o mouse nos quadrados do resumo (atributo data-tip); o
# <title> do SVG nao aparece no Viewer do RStudio
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

setup_server <- function(id, st, root, on_apply = function() NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    legendas <- c(audio_dir = "Folder of the recordings",
                  selection_dir = "Folder of the BirdNET selection tables",
                  output_dir = "Validation folder")
    lapply(names(setup_fields), function(nome) {
      shiny::observeEvent(input[[paste0(nome, "_browse")]], {
        d <- choose_dir(input[[nome]], legendas[[nome]])
        if (is.null(d)) {
          shiny::showNotification(
            "No folder was chosen. You can also type the path.",
            type = "message")
        } else {
          shiny::updateTextInput(session, nome, value = d)
        }
      })
    })

    shiny::observeEvent(input$apply, {
      novo <- lapply(names(setup_fields), function(n) {
        v <- trimws(if (is.null(input[[n]])) "" else input[[n]])
        if (nzchar(v)) sub("/+$", "", path.expand(v)) else NULL
      })
      names(novo) <- names(setup_fields)
      padrao <- trimws(if (is.null(input$site_pattern)) "" else
        input$site_pattern)
      # list(NULL) guarda o NULL (novo$x <- NULL apagaria o elemento)
      novo["site_pattern"] <- list(if (nzchar(padrao)) padrao else NULL)
      for (n in c("audio_dir", "selection_dir")) {
        if (!is.null(novo[[n]]) && !dir.exists(novo[[n]])) {
          shiny::showNotification(
            paste0(setup_fields[[n]], ": ", novo[[n]], " does not exist."),
            type = "error", duration = NULL)
          return()
        }
      }
      chaves <- c(names(setup_fields), "site_pattern", "clips_dir",
                  "verdicts_file", "manifest", "recordings_file",
                  "recordings")
      antes <- mget(chaves, envir = st)
      if (!identical(antes$output_dir, novo$output_dir)) {
        st$clips_dir <- NULL
        st$verdicts_file <- NULL
        st$manifest <- NULL
      }
      for (n in names(novo)) assign(n, novo[[n]], envir = st)
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
        for (n in chaves) assign(n, antes[[n]], envir = st)
        try(suppressWarnings(suppressMessages(load_app_state(st))),
            silent = TRUE)
        return()
      }
      st$confirmed <- TRUE
      on_apply()
      root$reload()
    })

    output$status <- shiny::renderUI({
      linha <- function(rotulo, valor) shiny::tags$li(shiny::strong(rotulo),
                                                      valor)
      det <- st$detections
      rec <- st$recordings
      shiny::tags$ul(
        linha("BirdNET predictions: ", if (is.null(det)) "none" else
          paste0(format(nrow(det), big.mark = ","), " from ",
                 n_distinct(det$site), " site folder(s)")),
        linha("Recordings: ", if (is.null(rec)) "none (choose the audio folder)"
              else paste0(nrow(rec), " at ", n_distinct(rec$site), " site(s)",
                          if (!is.null(st$recordings_file))
                            paste0(", in ", st$recordings_file))),
        linha("Clip manifest: ", if (is.character(st$manifest))
          st$manifest else if (is.null(st$manifest)) "none yet" else
            "a table given to run_app()"),
        linha("Clips to review: ", if (is.null(st$fila)) "0" else
          nrow(st$fila)))
    })

    output$summary <- shiny::renderUI({
      esp <- input$species
      tab <- recording_summary(st$recordings, st$detections, species = esp)
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
                   shiny::HTML(summary_svg(tab, species = esp))))
    })
  })
}

# Abre perguntando se as pastas dadas a run_app() ainda valem
confirm_folders <- function(st, input, session) {
  if (isTRUE(st$confirmed) || length(st$given) == 0) return(invisible())
  itens <- lapply(names(st$given), function(n) {
    # caminhos longos quebram a linha em vez de sair da janela
    shiny::tags$li(shiny::strong(paste0(setup_fields[[n]], ": ")),
                   shiny::code(st$given[[n]],
                               style = paste("white-space: normal;",
                                             "word-break: break-all;")))
  })
  shiny::showModal(shiny::modalDialog(
    title = "Are these folders still right?",
    shiny::p("run_app() was given:"),
    shiny::tags$ul(itens),
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
# Resumo das gravacoes: local x noite

# Uma linha por local x noite: gravacoes, horas gravadas, horas com alguma
# predicao (qualquer score) e o total de predicoes. Antes de `dawn_hour`, a
# gravacao e da noite anterior, como em score_detections(). Sem a lista de
# gravacoes, usa os arquivos de todas as predicoes. `species` limita so as
# contagens de predicoes, nao as gravacoes.
recording_summary <- function(recordings = NULL, detections = NULL,
                              species = NULL, dawn_hour = 12) {
  de_det <- is.null(recordings)
  if (de_det) {
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
                arquivo = basename(remap_path(recordings$source_audio)))
  rec <- bind_cols(rec, parse_date_hour(rec$arquivo)) |>
    filter(!is.na(recording_date)) |>
    distinct(arquivo, .keep_all = TRUE) |>
    mutate(night = night_of(recording_date, recording_hour, dawn_hour))
  if (nrow(rec) == 0) return(NULL)
  noite <- rec |>
    group_by(site, night) |>
    summarise(n_recordings = n(),
              hours_recorded = n_distinct(recording_date, recording_hour),
              .groups = "drop")
  if (!is.null(detections) && nrow(detections) > 0) {
    det <- count(tibble(arquivo = basename(remap_path(detections$begin_path))),
                 arquivo, name = "n_det")
    horas <- inner_join(rec, det, by = "arquivo") |>
      group_by(site, night) |>
      summarise(n_detections = sum(n_det),
                hours_with_detections = n_distinct(recording_date,
                                                   recording_hour),
                .groups = "drop")
    noite <- left_join(noite, horas, by = c("site", "night")) |>
      mutate(n_detections = replace_na(n_detections, 0L),
             hours_with_detections = replace_na(hours_with_detections, 0L))
  } else {
    noite$n_detections <- NA_integer_
    noite$hours_with_detections <- NA_integer_
  }
  noite$prop_hours <- noite$hours_with_detections / noite$hours_recorded
  attr(noite, "from_detections") <- de_det
  noite
}

# Cor de uma proporcao (0 a 1) numa escala sequencial
summary_colour <- function(p) {
  paleta <- c("#f4f1d0", "#c9e4a4", "#7cc49d", "#2e8f9e", "#22507e")
  rgb <- t(vapply(paleta, function(h) strtoi(substring(h, c(2, 4, 6),
                                                       c(3, 5, 7)), 16L),
                  numeric(3)))
  vapply(p, function(x) {
    if (is.na(x)) return("#d9d9d9")
    pos <- 1 + min(max(x, 0), 1) * (length(paleta) - 1)
    i <- min(floor(pos), length(paleta) - 1)
    f <- pos - i
    v <- round(rgb[i, ] * (1 - f) + rgb[i + 1, ] * f)
    sprintf("#%02x%02x%02x", v[1], v[2], v[3])
  }, character(1))
}

summary_svg <- function(tab, species = NULL) {
  quais <- if (length(species) == 0) "any species" else
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
  noites <- sort(unique(tab$night))
  cel <- 34
  rot <- max(nchar(sites))
  esq <- 96
  topo <- 20 + min(rot, 30) * 5.2
  larg <- max(esq + length(sites) * cel + 20, 380)
  alt_grade <- length(noites) * cel
  alt <- topo + alt_grade + 120
  max_n <- max(tab$n_recordings)
  lado <- function(n) 8 + (cel - 12) * sqrt(n / max_n)
  fmt_noite <- function(d) paste(substr(d, 1, 4), substr(d, 5, 6),
                               substr(d, 7, 8), sep = "-")
  s <- sprintf(paste0('<svg xmlns="http://www.w3.org/2000/svg" width="%d" ',
                      'height="%d" font-family="sans-serif" font-size="12">'),
               round(larg), round(alt))
  for (i in seq_along(sites)) {
    x <- esq + (i - 0.5) * cel
    s <- paste0(s, sprintf(paste0('<text transform="translate(%.1f %.1f) ',
                                  'rotate(-50)" fill="#333">%s</text>'),
                           x + 4, topo - 6, esc(sites[i])))
  }
  for (j in seq_along(noites)) {
    y <- topo + (j - 0.5) * cel
    s <- paste0(s, sprintf('<text x="%d" y="%.1f" text-anchor="end" fill="#333">%s</text>',
                           esq - 8, y + 4, fmt_noite(noites[j])))
  }
  for (k in seq_len(nrow(tab))) {
    r <- tab[k, ]
    i <- match(r$site, sites)
    j <- match(r$night, noites)
    cx <- esq + (i - 0.5) * cel
    cy <- topo + (j - 0.5) * cel
    l <- lado(r$n_recordings)
    dica <- paste0(
      r$site, ", night of ", fmt_noite(r$night), "\n",
      r$n_recordings, " recording(s), ", r$hours_recorded, " hour(s)",
      if (!is.na(r$n_detections)) paste0(
        "\n", r$hours_with_detections, " of ", r$hours_recorded,
        " hour(s) with predictions (", round(100 * r$prop_hours), "%)",
        "\n", format(r$n_detections, big.mark = ","),
        " prediction(s) of ", quais, ", any score"))
    s <- paste0(s, sprintf(
      paste0('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="3" ',
             'fill="%s" stroke="#555" stroke-width="0.6" data-tip="%s" ',
             'style="cursor: pointer;"/>'),
      cx - l / 2, cy - l / 2, l, l, summary_colour(r$prop_hours), esc(dica)))
  }
  # legendas: tamanho e cor
  y0 <- topo + alt_grade + 28
  s <- paste0(s, sprintf('<text x="%d" y="%.1f" fill="#333">Recordings</text>',
                         esq - 80, y0 + 4))
  ns_leg <- unique(c(1, round(max_n / 2), max_n))
  x <- esq
  for (n in ns_leg) {
    l <- lado(n)
    s <- paste0(s, sprintf(paste0('<rect x="%.1f" y="%.1f" width="%.1f" ',
                                  'height="%.1f" rx="3" fill="#ffffff" ',
                                  'stroke="#555" stroke-width="0.6"/>',
                                  '<text x="%.1f" y="%.1f" fill="#333">%d</text>'),
                           x, y0 - l / 2, l, l, x + l + 4, y0 + 4, n))
    x <- x + l + 30
  }
  y1 <- y0 + cel / 2 + 44
  s <- paste0(s, sprintf('<text x="%d" y="%.1f" fill="#333">Hours with predictions</text>',
                         esq - 80, y1 - 14))
  paradas <- vapply(0:4, function(q) sprintf(
    '<stop offset="%d%%" stop-color="%s"/>', q * 25, summary_colour(q / 4)),
    character(1))
  s <- paste0(s, '<defs><linearGradient id="sheepdog-prop">',
              paste(paradas, collapse = ""), '</linearGradient></defs>',
              sprintf(paste0('<rect x="%d" y="%.1f" width="160" height="10" ',
                             'fill="url(#sheepdog-prop)" stroke="#555" ',
                             'stroke-width="0.6"/>',
                             '<text x="%d" y="%.1f" fill="#333">0%%</text>',
                             '<text x="%d" y="%.1f" text-anchor="end" ',
                             'fill="#333">100%%</text>'),
                      esq, y1 - 4, esq, y1 + 20, esq + 160, y1 + 20),
              '</svg>')
  s
}
