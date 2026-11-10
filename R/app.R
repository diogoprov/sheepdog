#' Sample, review and export clips in a local app
#'
#' Opens a 'shiny' app, in the browser, for stages 1 and 2 of the
#' workflow. The tabs depend on the arguments:
#'
#' * **Intro**: a graphical abstract of the sampling designs and an Audio
#'   panel to choose the audio folder, the BirdNET results and the
#'   validation folder (with a dialog of the system), with a summary of the
#'   recordings per site and night. Folders given to `run_app()` are
#'   confirmed when the app opens. Without them, the app opens on this tab.
#' * **Sampling** (with `selection_dir` and `output_dir`): a form for the
#'   sampling design of [select_clips()]. *Draw* shows the clips per site
#'   and species and their inclusion probabilities without touching the
#'   audio; *Cut clips* cuts them with [cut_clips()] and writes
#'   `clip_manifest.csv`, `extraction_info.csv` and `clips/` to
#'   `output_dir`, as [extract_validation_clips()] does (without the zip
#'   packages). The new clips go straight to the Review tab.
#' * **Review**: the clips of a manifest one at a time, with the
#'   spectrogram and a player for each clip, its site, night, hour, score
#'   and design, and buttons to mark it positive, negative or uncertain.
#'   Each verdict is written at once to `verdicts_file`, so an interrupted
#'   session loses nothing and can be resumed. The tab replaces moving the
#'   clips into `Positive` and `Negative` folders in the BirdNET GUI;
#'   [app_verdicts()] turns `verdicts_file` into the table that
#'   [classify_review()] returns.
#' * **Export** (with `selection_dir` and `output_dir`): calls
#'   [export_occupancy_data()] with the detections of `selection_dir`, the
#'   verdicts of the Review tab (combined by [consensus_verdicts()] when a
#'   clip has several reviewers) and, optionally, `recordings`, and shows
#'   the summary of `schema.json`. The score calibration is not in the app
#'   yet; call [export_occupancy_data()] with `fit` for it.
#'
#' The app runs on the reviewer's computer and reads the clips from disk;
#' nothing is uploaded.
#'
#' @section Keyboard:
#' In the Review tab: `p` positive, `n` negative, `u` uncertain, right
#' arrow next clip, left arrow previous clip, space play or pause.
#'
#' @section Verdicts file:
#' A CSV with one line per click: `clip_file`, `species_folder`,
#' `reviewer`, `verdict` (`"positive"`, `"negative"` or `"uncertain"`) and
#' `time`. Lines are only appended; when a clip is marked again, the last
#' verdict of the reviewer counts. Several reviewers can share one file or
#' keep one each.
#'
#' @param manifest Clip manifest: a data frame or the path to
#'   `clip_manifest.csv` (from [select_clips()], [cut_clips()] or
#'   [assign_reviewers()]). With `output_dir`, by default
#'   `<output_dir>/clip_manifest.csv` when it exists.
#' @param clips_dir Folder of the cut clips, with one subfolder per
#'   species (`<clips_dir>/<species_folder>/<clip_file>`, as written by
#'   [cut_clips()]). With `output_dir`, `<output_dir>/clips` by default.
#' @param verdicts_file CSV where the verdicts are written. By default,
#'   `verdicts.csv` in `output_dir` or next to `manifest` when it is a
#'   path.
#' @param reviewer Name of the reviewer, written with each verdict. With a
#'   manifest from [assign_reviewers()], only the clips assigned to this
#'   reviewer (as first or second reviewer) are shown.
#' @param max_freq Upper limit of the spectrogram, in kHz: 12 by default
#'   (e.g. `8` for most anuran calls). `NULL` shows the whole band. It can
#'   also be changed in the Review tab.
#' @param selection_dir Folder of the BirdNET selection tables (as in
#'   [read_selection_tables()]). Opens the Sampling and Export tabs.
#' @param output_dir Folder of the validation round: the clips, the
#'   manifest, the verdicts and the export (`<output_dir>/occupancy` by
#'   default) are written there.
#' @param recordings Optional table of all recordings (columns `site` and
#'   `source_audio`), or the path to its CSV: needed by
#'   `"random_recordings"` and, in the export, to keep the occasions
#'   without detections (see [export_occupancy_data()]).
#' @param audio_dir Optional folder of the recordings, subfolders included.
#'   Every recording is listed with [list_recordings()] and written to the
#'   `recordings` CSV when it is a path, or else to
#'   `<output_dir>/recordings.csv`; the list is used as `recordings`.
#'   Can also be chosen in the app (Intro > Audio panel).
#' @param site_pattern Optional regular expression with one capture group
#'   that takes the site from the file names, when the recordings or the
#'   selection tables of several sites share a folder (see
#'   [list_recordings()] and [read_selection_tables()]). Can also be set in
#'   the Audio panel.
#' @param classifier Label of the classifier, recorded in
#'   `extraction_info.csv` and `schema.json`.
#' @param launch.browser Open the app in the browser? Passed to
#'   [shiny::runApp()].
#' @param ... Further arguments to [shiny::runApp()], e.g. `port`.
#'
#' @return Called for its side effect; returns when the app is closed.
#' @seealso [app_verdicts()], `vignette("review-app")`.
#' @export
#' @examples
#' \dontrun{
#' # Review only
#' run_app("validation/clip_manifest.csv", "validation/clips",
#'         reviewer = "liliana")
#'
#' # Sample, cut, review and export
#' run_app(selection_dir = "N:/Arara", output_dir = "validation",
#'         recordings = "recordings.csv", reviewer = "liliana",
#'         max_freq = 8)
#' }
run_app <- function(manifest = NULL, clips_dir = NULL, verdicts_file = NULL,
                    reviewer = NULL, max_freq = 12, selection_dir = NULL,
                    output_dir = NULL, recordings = NULL, audio_dir = NULL,
                    site_pattern = NULL, classifier = NULL,
                    launch.browser = interactive(), ...) {
  require_suggested("shiny", "to run the review app")
  require_suggested("av", "to draw the spectrograms")
  if (!is.null(manifest) && is.null(clips_dir) && is.null(output_dir)) {
    stop("Give `clips_dir` with `manifest`, or `output_dir`.", call. = FALSE)
  }
  if (!is.null(manifest) && !is.character(manifest) &&
      is.null(verdicts_file) && is.null(output_dir)) {
    stop("Give `verdicts_file` when `manifest` is a data frame.",
         call. = FALSE)
  }
  st <- app_state(manifest = manifest, clips_dir = clips_dir,
                  verdicts_file = verdicts_file, reviewer = reviewer,
                  max_freq = max_freq, selection_dir = selection_dir,
                  output_dir = output_dir, recordings = recordings,
                  audio_dir = audio_dir, site_pattern = site_pattern,
                  classifier = classifier)
  load_app_state(st)
  if (!is.null(st$fila)) {
    message(nrow(st$fila), " clip(s) to review; verdicts written to ",
            st$verdicts_file, ".")
  }
  shiny::runApp(review_app(st), launch.browser = launch.browser, ...)
}

#' Verdicts of the review app
#'
#' Joins the verdicts written by [run_app()] to the clip manifest, giving
#' the same table as [classify_review()] (the content of
#' `validation_by_clip.csv`), so that the summaries of stage 1, the
#' agreement between reviewers and the calibration work as with a review
#' in the BirdNET GUI. `"uncertain"` verdicts are kept but, like
#' `"disagreement"`, left out of precision, thresholds and calibration,
#' which use only positive and negative verdicts.
#'
#' @inheritParams run_app
#' @param verdicts_file CSV written by [run_app()].
#' @param clips_dir Optional folder of the clips, to fill `reviewed_path`
#'   (needed by [build_training_set()]).
#' @param reviewer Optional reviewer: only their verdicts are used. With
#'   `NULL`, every reviewer's verdicts are kept, one row per clip and
#'   reviewer, ready for [reviewer_agreement()] and
#'   [consensus_verdicts()].
#'
#' A clip marked more than once by the same reviewer keeps the last
#' verdict; a message says how many clips were marked again and how many of
#' them changed verdict.
#'
#' @return The manifest with `verdict` (`"positive"`, `"negative"`,
#'   `"uncertain"` or `"not_reviewed"`), `reviewed_path` and `reviewer`.
#'   With `reviewer = NULL`, a clip reviewed by two reviewers has two
#'   rows, and a clip not yet reviewed has one row with `reviewer = NA`.
#' @seealso [run_app()], [classify_review()].
#' @export
app_verdicts <- function(manifest, verdicts_file, clips_dir = NULL,
                         reviewer = NULL) {
  manifesto <- read_manifest(manifest)
  log <- read_verdict_log(verdicts_file, last_only = FALSE)
  if (!is.null(reviewer)) log <- log[log$reviewer %in% reviewer, ]
  report_remarked(log)
  log <- last_verdicts(log)
  fora <- setdiff(log$clip_file, manifesto$clip_file)
  if (length(fora) > 0) {
    warning(length(fora), " clip(s) of `verdicts_file` are not in the ",
            "manifest and were left out.", call. = FALSE)
  }
  log <- select(log, clip_file, species_folder, reviewer, verdict)
  chave <- intersect(c("clip_file", "species_folder"), names(manifesto))
  base <- select(manifesto, -any_of(c("verdict", "reviewed_path",
                                      "reviewer", "second_reviewer")))
  out <- left_join(base, log[c(chave, "reviewer", "verdict")], by = chave,
                   relationship = "one-to-many") |>
    mutate(verdict = replace_na(verdict, "not_reviewed"),
           reviewed_path = if (is.null(clips_dir)) NA_character_ else
             file.path(clips_dir, species_folder, clip_file))
  out <- fill_inherited(out)
  if (!is.null(reviewer)) out$reviewer <- reviewer
  contagem <- count(out, verdict)
  message("Clips in the manifest: ", nrow(manifesto), "\n",
          paste0("  ", contagem$verdict, ": ", contagem$n, collapse = "\n"))
  out
}

# Quantos clipes cada revisor marcou mais de uma vez, e quantos com
# vereditos diferentes
report_remarked <- function(log) {
  vezes <- log |>
    group_by(clip_file, species_folder, reviewer) |>
    summarise(n = n(), n_verdicts = n_distinct(verdict), .groups = "drop")
  remarcados <- sum(vezes$n > 1)
  if (remarcados > 0) {
    message(remarcados, " clip(s) marked more than once by the same ",
            "reviewer, ", sum(vezes$n_verdicts > 1), " of them with ",
            "different verdicts; the last verdict counts.")
  }
  invisible(vezes)
}

# Clipes da fila do app: os do revisor (com assign_reviewers()) e o
# caminho de cada um
review_queue <- function(manifest, clips_dir, reviewer = NULL) {
  fila <- read_manifest(manifest)
  fila <- fila[!is_inherited(fila), ]
  faltam <- setdiff(c("clip_file", "species_folder"), names(fila))
  if (length(faltam) > 0) {
    stop("`manifest` lacks the column(s): ", paste(faltam, collapse = ", "),
         call. = FALSE)
  }
  if (!is.null(reviewer) && "reviewer" %in% names(fila)) {
    segundo <- if ("second_reviewer" %in% names(fila)) {
      fila$second_reviewer %in% reviewer
    } else {
      FALSE
    }
    fila <- fila[fila$reviewer %in% reviewer | segundo, ]
    if (nrow(fila) == 0) {
      stop("No clip of the manifest is assigned to reviewer `", reviewer,
           "`.", call. = FALSE)
    }
  }
  for (col in c("site", "night", "recording_hour", "confidence",
                "sampling_mode", "species_code")) {
    if (!col %in% names(fila)) fila[[col]] <- NA
  }
  fila$path <- file.path(clips_dir, fila$species_folder, fila$clip_file)
  ausentes <- sum(!file.exists(fila$path))
  if (ausentes == nrow(fila)) {
    stop("None of the clips was found in `clips_dir` (",
         clips_dir, "/<species_folder>/<clip_file>).", call. = FALSE)
  }
  if (ausentes > 0) {
    warning(ausentes, " clip(s) not found in `clips_dir`; they are shown ",
            "without audio.", call. = FALSE)
  }
  fila
}

verdict_columns <- c("clip_file", "species_folder", "reviewer", "verdict",
                     "time")

# Acrescenta um veredito ao arquivo (cria com cabecalho se nao existe)
append_verdict <- function(file, clip_file, species_folder, reviewer,
                           verdict) {
  linha <- tibble(clip_file = clip_file, species_folder = species_folder,
                  reviewer = if (is.null(reviewer)) NA_character_ else
                    reviewer,
                  verdict = verdict,
                  time = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"))
  novo <- !file.exists(file)
  if (novo) dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  write_csv(linha, file, append = !novo, col_names = novo, na = "")
  invisible(linha)
}

# Ultimo veredito de cada clipe e revisor (com last_only = FALSE, todas as
# linhas, na ordem dos cliques)
read_verdict_log <- function(file, last_only = TRUE) {
  vazio <- tibble(clip_file = character(), species_folder = character(),
                  reviewer = character(), verdict = character(),
                  time = character())
  if (!file.exists(file)) return(vazio)
  # 0 bytes: sem cabecalho, os vereditos novos seriam gravados sem ele
  if (file.size(file) == 0) {
    stop("`verdicts_file` is empty (0 bytes): ", file, ". Delete it to ",
         "start a new log, or restore the copy with the verdicts.",
         call. = FALSE)
  }
  log <- read_csv(file, na = "", show_col_types = FALSE,
                  col_types = readr::cols(.default = readr::col_character()))
  faltam <- setdiff(verdict_columns, names(log))
  if (length(faltam) > 0) {
    stop("`verdicts_file` lacks the column(s): ",
         paste(faltam, collapse = ", "), call. = FALSE)
  }
  invalidos <- setdiff(log$verdict, c("positive", "negative", "uncertain"))
  if (length(invalidos) > 0) {
    stop("Unknown verdict(s) in `verdicts_file`: ",
         paste(invalidos, collapse = ", "), call. = FALSE)
  }
  if (!last_only) return(log)
  last_verdicts(log)
}

# a ordem das linhas e a ordem dos cliques: vale a ultima
last_verdicts <- function(log) {
  log$.ordem <- seq_len(nrow(log))
  log |>
    arrange(desc(.ordem)) |>
    distinct(clip_file, species_folder, reviewer, .keep_all = TRUE) |>
    arrange(.ordem) |>
    select(-.ordem)
}

# Paletas do espectrograma: rotulo -> paleta de grDevices::hcl.colors()
spectrogram_palettes <- c("Gray" = "Grays", "Viridis" = "Viridis",
                          "Inferno" = "Inferno", "Mako" = "Mako",
                          "Heat" = "Heat")
spectrogram_fft <- c(256L, 512L, 1024L, 2048L)

# Espectrograma de um clipe (av), com margens pequenas para caber no app.
# O av devolve valores menores onde o som e mais forte: no cinza, o som
# forte fica preto sobre o branco; nas paletas de cor, fica claro sobre o
# escuro. `fft`: tamanho da janela de Hann; `overlap`: sobreposicao.
plot_spectrogram <- function(path, max_freq = NULL, fft = 1024L,
                             overlap = 0.9, palette = "Gray",
                             brightness = 0, contrast = 1) {
  x <- av::read_audio_fft(path, window = av::hanning(fft),
                          overlap = overlap)
  freq <- attr(x, "frequency") / 1000
  manter <- if (is.null(max_freq)) TRUE else freq <= max_freq
  z <- t(x[manter, , drop = FALSE])
  # escala de 0 (som mais forte) a 1 (silencio): a metade mais silenciosa
  # dos pixels fica no fundo. O contraste estica a escala em torno do meio;
  # o brilho clareia a imagem (no cinza, vai para o branco; nas paletas de
  # cor, para a ponta clara, a do som forte).
  teto <- stats::quantile(z, 0.5, names = FALSE)
  piso <- min(z)
  v <- if (teto > piso) (pmin(z, teto) - piso) / (teto - piso) else z * 0
  v <- (v - 0.5) * contrast + 0.5
  v <- v + if (identical(palette, "Gray")) brightness else -brightness
  v <- pmin(pmax(v, 0), 1)
  op <- graphics::par(mar = c(4, 4, 0.5, 0.5))
  on.exit(graphics::par(op))
  # o topo do eixo e o pedido, nao a ultima faixa de frequencia do FFT
  topo <- if (is.null(max_freq)) max(freq) else min(max_freq, max(freq))
  graphics::image(attr(x, "time"), freq[manter], v, zlim = c(0, 1),
                  ylim = c(0, topo), col = spectrogram_colours(palette),
                  xlab = "Time (s)", ylab = "Frequency (kHz)",
                  useRaster = TRUE)
  # regiao do grafico e eixos, para a linha que acompanha o audio
  invisible(list(plt = graphics::par("plt"), usr = graphics::par("usr")))
}

# Linha tracejada que acompanha o audio sobre o espectrograma. O servidor
# manda a regiao do grafico (fracoes da imagem) e o intervalo de tempo.
playhead_js <- "
$(function() {
  var cfg = {};
  Shiny.addCustomMessageHandler('sheepdog-playhead', function(m) {
    cfg[m.line] = m;
  });
  function step() {
    for (var id in cfg) {
      var m = cfg[id], line = document.getElementById(id);
      if (!line) continue;
      var img = line.parentElement.querySelector('img');
      var au = document.querySelector('#' + m.player + ' audio');
      if (!img || !au || !img.clientWidth) { line.style.display = 'none'; continue; }
      var f = (au.currentTime - m.t0) / (m.t1 - m.t0);
      f = Math.max(0, Math.min(1, f));
      var W = img.clientWidth, H = img.clientHeight;
      line.style.left = (img.offsetLeft + W * (m.plt[0] + f * (m.plt[1] - m.plt[0]))) + 'px';
      line.style.top = (img.offsetTop + H * (1 - m.plt[3])) + 'px';
      line.style.height = (H * (m.plt[3] - m.plt[2])) + 'px';
      line.style.borderLeftColor = m.colour || '#d62728';
      line.style.display = 'block';
    }
    window.requestAnimationFrame(step);
  }
  window.requestAnimationFrame(step);
});"

spectrogram_colours <- function(palette = "Gray") {
  if (identical(palette, "Gray") || !palette %in% names(spectrogram_palettes)) {
    return(grDevices::gray.colors(64, start = 0, end = 1))
  }
  # o som forte (valores baixos) recebe a ponta clara da paleta
  grDevices::hcl.colors(64, spectrogram_palettes[[palette]], rev = TRUE)
}

# Teclas do app
review_keys <- c(p = "positive", n = "negative", u = "uncertain")

# Interface do app a partir do estado: so a revisao, ou as abas Intro,
# Sampling, Review e Export (as duas do meio pedem as pastas quando faltam)
app_ui <- function(st) {
  titulo <- paste0("sheepdog", if (!is.null(st$reviewer))
    paste0(" (", st$reviewer, ")"))
  if (st$review_only) {
    return(shiny::fluidPage(title = "sheepdog review",
                            shiny::titlePanel(paste0(titulo,
                                                     ": clip review")),
                            review_ui("review", st$max_freq)))
  }
  pronto <- app_ready(st)
  shiny::navbarPage(
    titulo, id = "tabs", selected = if (is.null(st$fila)) "Intro" else
      "Review",
    shiny::tabPanel("Intro", intro_ui(st)),
    shiny::tabPanel("Sampling", if (pronto) {
      sampling_ui("sampling", st$detections, st$audio_dir)
    } else needs_folders_ui()),
    shiny::tabPanel("Review", review_ui("review", st$max_freq)),
    shiny::tabPanel("Export", if (pronto) {
      export_ui("export", st$output_dir)
    } else needs_folders_ui()))
}

# O app: interface e servidor. Sem `detections`, so a aba de revisao
review_app <- function(st) {
  recurso <- "sheepdog_clips"
  shiny::addResourcePath("sheepdog_app",
                         system.file("app", package = "sheepdog"))
  registrar_clipes <- function() {
    if (is.null(st$clips_dir)) return(invisible())
    dir.create(st$clips_dir, recursive = TRUE, showWarnings = FALSE)
    shiny::addResourcePath(recurso, normalizePath(st$clips_dir))
  }
  registrar_clipes()
  # a interface e montada a cada carga da pagina, a partir do estado
  ui <- function(req) app_ui(st)
  server <- function(input, output, session) {
    fila_r <- shiny::reactiveVal(st$fila)
    if (!st$review_only) {
      setup_server("setup", st, session, registrar_clipes)
      confirm_folders(st, input, session)
    }
    if (!st$review_only && app_ready(st)) {
      output_dir <- st$output_dir
      cortes <- sampling_server("sampling", st$detections, st$selection_dir,
                                output_dir, st$recordings, st$classifier,
                                audio_listed = st$audio_dir)
      # clipes recem-cortados vao para a fila da revisao
      shiny::observeEvent(cortes(), {
        q <- tryCatch(
          review_queue(file.path(output_dir, "clip_manifest.csv"),
                       st$clips_dir, st$reviewer),
          error = function(e) {
            shiny::showNotification(conditionMessage(e), type = "warning",
                                    duration = NULL)
            NULL
          })
        fila_r(q)
        st$fila <- q
        if (!is.null(q)) shiny::updateNavbarPage(session, "tabs", "Review")
      }, ignoreInit = TRUE)
      export_server("export", st$detections, output_dir, st$clips_dir,
                    st$verdicts_file, st$recordings, st$classifier)
    }
    review_server("review", fila_r, st$verdicts_file, st$reviewer, recurso,
                  st$max_freq)
  }
  shiny::shinyApp(ui = ui, server = server)
}

review_ui <- function(id, max_freq = 12) {
  ns <- shiny::NS(id)
  teclas <- sprintf(
    "document.addEventListener('keydown', function(e) {
       if (['INPUT', 'SELECT', 'TEXTAREA'].includes(e.target.tagName)) return;
       if (e.key === ' ') {
         var au = document.querySelector('#%s audio');
         if (au) { e.preventDefault(); if (au.paused) au.play(); else au.pause(); }
         return;
       }
       Shiny.setInputValue('%s', e.key, {priority: 'event'});
     });", ns("player"), ns("key"))
  shiny::tagList(
    shiny::tags$head(shiny::tags$script(shiny::HTML(teclas)),
                     shiny::tags$script(shiny::HTML(playhead_js)),
                     shiny::tags$style(shiny::HTML(
                       paste("td { white-space: nowrap; }",
                             "td + td { white-space: normal;",
                             "word-break: break-all; }")))),
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        width = 3,
        shiny::selectInput(ns("species"), "Species", c("All" = "")),
        hint("Show only the clips of this species."),
        shiny::checkboxInput(ns("pending"), "Only clips not yet reviewed",
                             value = TRUE),
        hint("Hide the clips that already have a verdict."),
        shiny::textOutput(ns("progress")),
        shiny::hr(),
        shiny::tableOutput(ns("info")),
        shiny::helpText("Keys: p positive, n negative, u uncertain,",
                        "right arrow next, left arrow previous, space play or pause.")
      ),
      shiny::mainPanel(
        width = 9,
        shiny::h4(shiny::textOutput(ns("position"), inline = TRUE),
                  style = "margin-top: 0;"),
        shiny::fluidRow(
          shiny::column(2, shiny::selectInput(
            ns("palette"), "Palette", names(spectrogram_palettes))),
          shiny::column(2, shiny::selectInput(
            ns("fft"), "FFT window", spectrogram_fft, selected = 1024L)),
          shiny::column(2, shiny::numericInput(
            ns("max_freq"), "Max. kHz",
            if (is.null(max_freq)) NA else max_freq, min = 0.5, step = 0.5)),
          shiny::column(3, shiny::sliderInput(
            ns("brightness"), "Brightness", min = -50, max = 50, value = 0,
            step = 5, post = "%", ticks = FALSE)),
          shiny::column(3, shiny::sliderInput(
            ns("contrast"), "Contrast", min = 25, max = 300, value = 100,
            step = 25, post = "%", ticks = FALSE))),
        shiny::fluidRow(shiny::column(12, hint(
          "FFT window in samples, with 90% overlap: larger windows sharpen",
          "the frequency and blur the time. Max. kHz is the top of the",
          "plot; empty shows the whole band."))),
        shiny::div(
          style = "position: relative;",
          shiny::plotOutput(ns("spectrogram"), height = "320px"),
          shiny::div(id = ns("playhead"), style = paste(
            "position: absolute; display: none; width: 0;",
            "border-left: 1px dashed #d62728; pointer-events: none;"))),
        shiny::uiOutput(ns("player")),
        shiny::br(),
        shiny::actionButton(ns("positive"), "Positive (p)",
                            class = "btn-success"),
        shiny::actionButton(ns("negative"), "Negative (n)",
                            class = "btn-danger"),
        shiny::actionButton(ns("uncertain"), "Uncertain (u)",
                            class = "btn-warning"),
        shiny::actionButton(ns("previous"), "< Previous"),
        shiny::actionButton(ns("next_clip"), "Next >"),
        shiny::br(), shiny::br(),
        shiny::textOutput(ns("current_verdict"))
      )
    )
  )
}

# `fila`: tabela de review_queue() ou um reativo que a devolve (NULL antes
# do corte dos clipes)
review_server <- function(id, fila, verdicts_file, reviewer, recurso = "",
                          max_freq = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    fila_r <- if (shiny::is.reactive(fila)) fila else shiny::reactive(fila)
    tab <- shiny::reactive({
      f <- fila_r()
      if (is.null(f)) f <- tibble(clip_file = character(),
                                  species_folder = character())
      f
    })
    chave <- shiny::reactive(paste(tab()$species_folder, tab()$clip_file,
                                   sep = "/"))
    lidos <- function() {
      log <- read_verdict_log(verdicts_file)
      rev <- if (is.null(reviewer)) NA_character_ else reviewer
      log <- log[log$reviewer %in% rev, ]
      stats::setNames(log$verdict,
                      paste(log$species_folder, log$clip_file, sep = "/"))
    }
    vereditos <- shiny::reactiveVal(lidos())
    atual <- shiny::reactiveVal(NA_integer_)
    shiny::observeEvent(tab(), {
      shiny::updateSelectInput(session, "species", choices = c(
        "All" = "", sort(unique(tab()$species_folder))))
    })

    # clipes visiveis com os filtros; o clipe atual continua visivel ate
    # o revisor sair dele
    visiveis <- shiny::reactive({
      f <- tab()
      ok <- rep(TRUE, nrow(f))
      if (!is.null(input$species) && nzchar(input$species)) {
        ok <- ok & f$species_folder == input$species
      }
      if (isTRUE(input$pending)) {
        ok <- ok & !chave() %in% names(shiny::isolate(vereditos()))
      }
      which(ok)
    })
    shiny::observeEvent(list(tab(), input$species, input$pending), {
      v <- visiveis()
      atual(if (length(v) > 0) v[1] else NA_integer_)
    })

    proximo <- function(passo) {
      v <- visiveis()
      i <- atual()
      if (is.na(i)) {
        atual(if (length(v) > 0) v[1] else NA_integer_)
        return(invisible())
      }
      depois <- if (passo > 0) v[v > i] else rev(v[v < i])
      if (length(depois) > 0) atual(depois[1])
    }
    marcar <- function(veredito) {
      i <- atual()
      if (is.na(i)) return(invisible())
      f <- tab()
      append_verdict(verdicts_file, f$clip_file[i], f$species_folder[i],
                     reviewer, veredito)
      vv <- vereditos()
      vv[chave()[i]] <- veredito
      vereditos(vv)
      proximo(1)
    }
    shiny::observeEvent(input$positive, marcar("positive"))
    shiny::observeEvent(input$negative, marcar("negative"))
    shiny::observeEvent(input$uncertain, marcar("uncertain"))
    shiny::observeEvent(input$next_clip, proximo(1))
    shiny::observeEvent(input$previous, proximo(-1))
    shiny::observeEvent(input$key, {
      k <- tolower(input$key)
      if (k %in% names(review_keys)) {
        marcar(review_keys[[k]])
      } else if (k == "arrowright") {
        proximo(1)
      } else if (k == "arrowleft") {
        proximo(-1)
      }
    })

    output$position <- shiny::renderText({
      i <- atual()
      feitos <- sum(chave() %in% names(vereditos()))
      n <- nrow(tab())
      if (is.na(i)) return(paste0(feitos, " of ", n, " clips reviewed"))
      paste0("Clip ", i, " of ", n, "  |  ", feitos, " of ", n,
             " clips reviewed")
    })
    output$progress <- shiny::renderText({
      feitos <- sum(chave() %in% names(vereditos()))
      paste0(feitos, " of ", nrow(tab()), " clips reviewed")
    })
    output$info <- shiny::renderTable({
      i <- atual()
      shiny::req(!is.na(i))
      f <- tab()
      tibble(field = c("Clip", "Species", "Site", "Night", "Hour",
                       "Score", "Design"),
             value = c(f$clip_file[i], f$species_folder[i],
                       as.character(f$site[i]),
                       as.character(f$night[i]),
                       as.character(f$recording_hour[i]),
                       format(f$confidence[i], digits = 3),
                       as.character(f$sampling_mode[i])))
    }, colnames = FALSE)
    output$current_verdict <- shiny::renderText({
      if (is.null(fila_r())) {
        return("No clips yet: draw and cut them in the Sampling tab.")
      }
      i <- atual()
      if (is.na(i)) return("No clip left with these filters.")
      v <- vereditos()[chave()[i]]
      if (is.na(v)) "Not reviewed yet." else paste("Current verdict:", v)
    })
    output$spectrogram <- shiny::renderPlot({
      i <- atual()
      shiny::req(!is.na(i), file.exists(tab()$path[i]))
      teto <- if (is.null(input$max_freq)) max_freq else input$max_freq
      if (is.null(teto) || is.na(teto) || teto <= 0) teto <- NULL
      fft <- suppressWarnings(as.integer(input$fft))
      if (length(fft) == 0 || is.na(fft)) fft <- 1024L
      pct <- function(x, padrao) if (is.null(x) || is.na(x)) padrao else
        x / 100
      g <- plot_spectrogram(tab()$path[i], teto, fft = fft, overlap = 0.9,
                            palette = if (is.null(input$palette)) "Gray" else
                              input$palette,
                            brightness = pct(input$brightness, 0),
                            contrast = pct(input$contrast, 1))
      session$sendCustomMessage("sheepdog-playhead", list(
        line = session$ns("playhead"), player = session$ns("player"),
        plt = g$plt, t0 = g$usr[1], t1 = g$usr[2],
        colour = if (identical(input$palette, "Gray") ||
                     is.null(input$palette)) "#d62728" else "#ffffff"))
    })
    output$player <- shiny::renderUI({
      i <- atual()
      shiny::req(!is.na(i), file.exists(tab()$path[i]))
      f <- tab()
      src <- paste(recurso, utils::URLencode(f$species_folder[i],
                                             reserved = TRUE),
                   utils::URLencode(f$clip_file[i], reserved = TRUE),
                   sep = "/")
      shiny::tags$audio(src = src, type = "audio/wav", controls = NA,
                        autoplay = NA, style = "width: 100%;")
    })
    invisible(list(current = atual, verdicts = vereditos, queue = tab))
  })
}

# Aba de abertura: a figura que resume os modos de amostragem
intro_ui <- function(st) {
  shiny::navlistPanel(
    id = "intro_nav", widths = c(2, 10), well = FALSE,
    shiny::tabPanel(
      "Graphical abstract",
      shiny::h3("How sheepdog picks the clips you review"),
      shiny::p("Each panel shows one night of 30-minute recordings",
               "(simulated scores) and which clips each sampling mode and",
               "occasion would give. Choose the design in the Sampling tab,",
               "review the clips in the Review tab and write the occupancy",
               "tables in the Export tab."),
      shiny::tags$img(src = "sheepdog_app/intro.png",
                      alt = "Sampling modes, occasions and strata of sheepdog",
                      style = "max-width: 100%; height: auto;")),
    shiny::tabPanel("Audio panel", setup_ui("setup", st)))
}

# Texto curto, cinza, sob o titulo de um campo
hint <- function(...) {
  shiny::tags$div(shiny::HTML(paste(...)), style = paste(
    "margin-top: -10px; margin-bottom: 12px;",
    "font-size: 0.85em; color: #6c757d;"))
}

# Titulo do limiar: obrigatorio so em "random_detections"
threshold_label <- function(mode) {
  paste0("Threshold of the occupancy analysis (",
         if (identical(mode, "random_detections")) "required" else "optional",
         ")")
}

# Presets de estratos de select_clips()
strata_presets <- c("night_hour", "night", "hour", "week", "month",
                    "site_species")

sampling_ui <- function(id, detections, audio_dir = NULL) {
  ns <- shiny::NS(id)
  sites <- sort(unique(as.character(detections$site)))
  especies <- sort(unique(str_extract(detections$species_code, "[^_]+$")))
  num <- function(nome, rotulo, valor = NA, ...) {
    shiny::numericInput(ns(nome), rotulo, valor, ...)
  }
  shiny::sidebarLayout(
    shiny::sidebarPanel(
      width = 4,
      shiny::selectInput(ns("mode"), "Sampling mode",
                         c("random_detections", "top", "random_recordings")),
      hint("<b>top</b>: only the highest-scored clips (n_top per night x",
           "hour), for retraining and calibration.",
           "<b>random_detections</b>: draw clips from occasions drawn at",
           "random among those with detections above the threshold; every",
           "detection above the threshold in a drawn occasion is a clip.",
           "<b>random_recordings</b>: draw recordings (or minutes) at",
           "random from everything recorded, with or without detections,",
           "to annotate by ear."),
      shiny::selectInput(ns("occasion_unit"), "Occasion", c("file", "minute")),
      hint("The unit of time over which a species counts as detected or",
           "not at a site: a whole file or one minute of it."),
      num("threshold", threshold_label("random_detections"),
          min = 0, max = 1, step = 0.05),
      hint("Score from which a prediction counts as a detection. Needed by",
           "random_detections; use the value of the occupancy analysis."),
      num("n_top", "n_top (per stratum, or per night x hour in top)", 2,
          min = 1),
      hint("<b>top</b>: clips kept per site x species x night x hour.",
           "<b>random_detections</b>: occasions drawn per stratum."),
      shiny::conditionalPanel(
        "input.mode == 'random_detections'", ns = ns,
        shiny::selectInput(ns("strata"), "Strata", strata_presets),
        hint("Groups, within each site x species, in which the occasions",
             "are drawn (e.g. night x hour).")),
      shiny::conditionalPanel(
        "input.mode == 'random_recordings'", ns = ns,
        num("recording_fraction", "Fraction of recordings per site", 0.01,
            min = 0, max = 1),
        hint("Share of the recordings (or minutes) of each site drawn, at",
             "least one per site.")),
      num("target_total", "Total clips per site (optional)", min = 1),
      hint("Split evenly among species. Not used by random_recordings."),
      num("max_per_species", "Maximum clips per site x species (optional)",
          min = 1),
      hint("A fixed limit per site and species. Ignored when a total per",
           "site is set."),
      num("min_confidence", "Minimum score", 0.1, min = 0, max = 1,
          step = 0.05),
      hint("top only: predictions below this score are skipped. The",
           "random modes use the threshold."),
      shiny::selectizeInput(ns("sites"), "Sites (all if empty)", sites,
                            multiple = TRUE),
      hint("Draw only from these sites."),
      shiny::selectizeInput(ns("species"), "Species (all if empty)",
                            especies, multiple = TRUE),
      hint("Draw only these species (short codes, e.g. boa-ran)."),
      shiny::fluidRow(
        shiny::column(6, num("hour_start", "From hour", min = 0, max = 23)),
        shiny::column(6, num("hour_end", "To hour", min = 0, max = 23))),
      hint("Hours of the day (0-23) to draw from. The window can cross",
           "midnight, e.g. 17 to 2."),
      num("seed", "Seed", 2026),
      hint("Fixes the random draw, so the same seed gives the same clips."),
      shiny::textInput(ns("remap_from"), "Remap audio paths from (optional)"),
      shiny::textInput(ns("remap_to"), "to"),
      hint("If the recordings moved since BirdNET ran, replace the start of",
           "their paths, e.g. N:/ by /Volumes/Arara/."),
      shiny::textInput(ns("audio_dir"), "Audio folder (optional)",
                       if (is.null(audio_dir)) "" else audio_dir),
      hint("Folder of the recordings (subfolders included). The app checks",
           "the audio paths after each draw; when some are missing, it",
           "looks for the files here by name and offers to use them."),
      shiny::actionButton(ns("draw"), "Draw", class = "btn-primary"),
      shiny::hr(),
      shiny::checkboxInput(ns("simulate"),
                           "Simulate (check the audio, cut nothing)"),
      hint("Shows what would be cut, without writing any audio."),
      shiny::checkboxInput(ns("replace"),
                           "Replace an existing clip_manifest.csv"),
      hint("Overwrites the manifest of an earlier cut in this round."),
      shiny::actionButton(ns("cut"), "Cut clips")
    ),
    shiny::mainPanel(
      width = 8,
      shiny::uiOutput(ns("notes")),
      shiny::uiOutput(ns("counts_title")),
      shiny::tableOutput(ns("counts")),
      shiny::uiOutput(ns("inclusion_title")),
      shiny::tableOutput(ns("inclusion")),
      shiny::uiOutput(ns("cut_title")),
      shiny::tableOutput(ns("cut_status"))
    )
  )
}

# Argumentos de select_clips() a partir do formulario: campos vazios
# ficam com o padrao da funcao
sampling_args <- function(input) {
  vazio <- function(x) is.null(x) || length(x) == 0 || all(is.na(x)) ||
    identical(x, "")
  args <- list(sampling_mode = input$mode,
               occasion_unit = input$occasion_unit,
               threshold = input$threshold, n_top = input$n_top,
               min_confidence = input$min_confidence, seed = input$seed,
               target_total = input$target_total,
               max_per_species = input$max_per_species,
               sites = input$sites, species = input$species,
               hour_start = input$hour_start, hour_end = input$hour_end,
               remap_from = input$remap_from, remap_to = input$remap_to)
  if (identical(input$mode, "random_detections")) {
    args$strata <- input$strata
  }
  if (identical(input$mode, "random_recordings")) {
    args$recording_fraction <- input$recording_fraction
  }
  args[!vapply(args, vazio, logical(1))]
}

# Roda uma funcao guardando os avisos e mensagens para mostrar no app
with_notes <- function(expr) {
  notas <- character()
  valor <- withCallingHandlers(
    expr,
    warning = function(w) {
      notas <<- c(notas, conditionMessage(w))
      invokeRestart("muffleWarning")
    },
    message = function(m) {
      notas <<- c(notas, trimws(conditionMessage(m)))
      invokeRestart("muffleMessage")
    })
  list(value = valor, notes = notas)
}

# Confere se as gravacoes existem e procura as ausentes, pelo nome do
# arquivo, em `audio_dir` (com subpastas). `found` liga cada caminho ausente
# ao achado; nomes repetidos em `audio_dir` ficam de fora (ambiguos).
# `remap` e o par de pastas quando um so explica todos os achados.
# `files`: os arquivos de `audio_dir`, quando ja listados (ex. pela aba Audio
# panel), para nao varrer a pasta de novo a cada sorteio.
locate_audio <- function(paths, audio_dir = NULL,
                         audio_pattern = "\\.(wav|flac|mp3)$",
                         files = NULL) {
  paths <- unique(paths[!is.na(paths) & nzchar(paths)])
  ausentes <- paths[!file.exists(paths)]
  achados <- character()
  remap <- NULL
  if (!is.null(audio_dir)) audio_dir <- sub("/+$", "", path.expand(audio_dir))
  if (length(ausentes) > 0 && !is.null(audio_dir) && nzchar(audio_dir) &&
      dir.exists(audio_dir)) {
    arquivos <- if (!is.null(files)) files else
      list.files(audio_dir, audio_pattern, recursive = TRUE,
                 full.names = TRUE, ignore.case = TRUE)
    arquivos <- str_replace_all(arquivos, fixed("\\"), "/")
    nomes <- basename(arquivos)
    unicos <- !(duplicated(nomes) | duplicated(nomes, fromLast = TRUE))
    idx <- match(basename(ausentes), nomes[unicos])
    achados <- stats::setNames(arquivos[unicos][idx[!is.na(idx)]],
                               ausentes[!is.na(idx)])
    if (length(achados) > 0) {
      pares <- unique(paste(dirname(names(achados)), dirname(achados),
                            sep = "\r"))
      if (length(pares) == 1) {
        remap <- paste0(strsplit(pares, "\r", fixed = TRUE)[[1]], "/")
      }
    }
  }
  list(n = length(paths), missing = ausentes, found = achados,
       remap = remap)
}

# Os arquivos ja listados de `listed_dir` servem para `audio_dir`? So quando
# as duas pastas sao a mesma
listed_files <- function(audio_dir, listed_dir, recordings) {
  mesma <- function(d) {
    if (is.null(d) || !nzchar(d) || !dir.exists(path.expand(d))) {
      return(NA_character_)
    }
    normalizePath(path.expand(d), winslash = "/")
  }
  a <- mesma(audio_dir)
  if (is.null(recordings) || is.na(a) || !identical(a, mesma(listed_dir))) {
    return(NULL)
  }
  as.character(recordings$source_audio)
}

# Aviso, apos o sorteio, sobre as gravacoes achadas ou ausentes
audio_note <- function(chk, audio_dir) {
  dado <- !is.null(audio_dir) && nzchar(audio_dir)
  if (length(chk$missing) == 0) {
    return(paste0("All ", chk$n, " recordings of the draw were found."))
  }
  if (dado && !dir.exists(path.expand(audio_dir))) {
    return(paste0("The audio folder ", audio_dir, " does not exist."))
  }
  if (length(chk$found) > 0) return(character())
  paste0(length(chk$missing), " of ", chk$n, " recordings of the draw ",
         "were not found (e.g. ", chk$missing[1], "). ",
         if (dado) paste0("They are not in ", audio_dir, " either.")
         else paste("Give the folder of the recordings in \"Audio folder\"",
                    "or fill the remap fields, and draw again."))
}

# Pergunta se o manifesto deve usar as gravacoes achadas em `audio_dir`
relocate_dialog <- function(chk, audio_dir, ns) {
  de <- names(chk$found)[1]
  shiny::modalDialog(
    title = "Use the recordings of the audio folder?",
    shiny::p(length(chk$missing), " of ", chk$n, " recordings of the draw ",
             "are not where the selection tables say. ",
             length(chk$found), " of them were found in ", audio_dir, "."),
    shiny::p("For example:"),
    shiny::tags$ul(
      shiny::tags$li("selection tables: ", shiny::code(de)),
      shiny::tags$li("audio folder: ", shiny::code(chk$found[[1]]))),
    if (!is.null(chk$remap)) {
      shiny::p("That is, ", shiny::code(chk$remap[1]), " becomes ",
               shiny::code(chk$remap[2]), ".")
    },
    shiny::p("The manifest keeps the BirdNET path in ", shiny::code("begin_path"),
             " and uses the new one in ", shiny::code("source_audio"), "."),
    footer = shiny::tagList(
      shiny::modalButton("Keep the paths"),
      shiny::actionButton(ns("relocate"), "Use the audio folder",
                          class = "btn-primary")),
    easyClose = FALSE)
}

# Devolve um reativo que muda a cada corte (o app recarrega a fila)
sampling_server <- function(id, detections, selection_dir, output_dir,
                            recordings = NULL, classifier = NULL,
                            audio_listed = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    selecao <- shiny::reactiveVal(NULL)
    args_r <- shiny::reactiveVal(NULL)
    notas <- shiny::reactiveVal(character())
    status <- shiny::reactiveVal(NULL)
    shiny::observeEvent(input$mode, {
      shiny::updateNumericInput(session, "threshold",
                                label = threshold_label(input$mode))
    })
    cortes <- shiny::reactiveVal(0L)
    audio <- shiny::reactiveVal(NULL)       # resultado de locate_audio()
    realocadas <- shiny::reactiveVal(NULL)  # gravacoes trocadas de pasta

    shiny::observeEvent(input$draw, {
      args <- sampling_args(input)
      if (identical(input$mode, "random_recordings")) {
        args$recordings <- recordings
      }
      r <- tryCatch(with_notes(do.call(select_clips,
                                       c(list(detections), args))),
                    error = function(e) {
                      list(value = NULL, notes = paste("Error:",
                                                       conditionMessage(e)))
                    })
      if (identical(input$mode, "top")) {
        r$notes <- c(r$notes, paste(
          "\"top\" clips serve retraining and calibration; they hold fewer",
          "false positives than a random sample and do not estimate the",
          "false-positive rate."))
      }
      args$recordings <- NULL
      selecao(r$value)
      args_r(args)
      status(NULL)
      realocadas(NULL)
      audio(NULL)
      if (!is.null(r$value) && nrow(r$value) > 0) {
        chk <- locate_audio(r$value$source_audio, input$audio_dir,
                            files = listed_files(input$audio_dir,
                                                 audio_listed, recordings))
        audio(chk)
        r$notes <- c(r$notes, audio_note(chk, input$audio_dir))
        if (length(chk$found) > 0) {
          shiny::showModal(relocate_dialog(chk, input$audio_dir,
                                           session$ns))
        }
      }
      notas(r$notes)
    })

    shiny::observeEvent(input$relocate, {
      chk <- audio()
      sel <- selecao()
      shiny::removeModal()
      if (is.null(chk) || is.null(sel)) return()
      idx <- match(sel$source_audio, names(chk$found))
      sel$source_audio[!is.na(idx)] <- unname(chk$found[idx[!is.na(idx)]])
      selecao(sel)
      realocadas(list(dir = input$audio_dir, n = length(chk$found),
                      remap = chk$remap))
      falta <- length(chk$missing) - length(chk$found)
      notas(c(
        paste0(length(chk$found), " recording(s) now read from ",
               input$audio_dir, "; the manifest will use these paths."),
        if (falta > 0) paste0(falta, " recording(s) are still missing.")))
    })

    shiny::observeEvent(input$cut, {
      sel <- selecao()
      if (is.null(sel)) {
        notas("Draw the clips first.")
        return()
      }
      caminho <- file.path(output_dir, "clip_manifest.csv")
      if (file.exists(caminho) && !isTRUE(input$replace)) {
        notas(paste("clip_manifest.csv already exists in", output_dir,
                    "- tick \"Replace\" to write over it (the verdicts",
                    "already given refer to its clips)."))
        return()
      }
      simular <- isTRUE(input$simulate)
      r <- with_notes(cut_clips(sel, output_dir, simulate = simular))
      nenhum <- all(r$value$status == "audio_not_found")
      if (!simular) {
        write_csv(r$value, caminho)
        info <- extraction_info(selection_dir, classifier, simular, args_r())
        re <- realocadas()
        if (!is.null(re)) {
          info <- bind_rows(info, tibble(
            key = c("audio_dir", "recordings_relocated"),
            value = c(re$dir, as.character(re$n))))
        }
        write_csv(info, file.path(output_dir, "extraction_info.csv"))
        r$notes <- c(r$notes, paste("Manifest written to", caminho))
      }
      if (nenhum) {
        r$notes <- c(r$notes, paste(
          "No recording was found, so no clip was cut. Give the folder of",
          "the recordings in \"Audio folder\" (or fill the remap fields),",
          "draw again and cut with \"Replace\" ticked."))
      }
      notas(r$notes)
      status(count(r$value, species_folder, status))
      if (!simular && !nenhum) cortes(cortes() + 1L)
    })

    output$notes <- shiny::renderUI({
      n <- notas()
      if (length(n) == 0) return(NULL)
      shiny::div(class = "alert alert-info",
                 lapply(n, function(x) shiny::p(x)))
    })
    # os titulos so aparecem com a tabela
    output$counts_title <- shiny::renderUI({
      shiny::req(selecao(), nrow(selecao()) > 0)
      shiny::h4("Clips per site and species")
    })
    output$inclusion_title <- shiny::renderUI({
      sel <- selecao()
      shiny::req(sel, nrow(sel) > 0, any(!is.na(sel$inclusion_prob)))
      shiny::h4("Inclusion probability per species")
    })
    output$cut_title <- shiny::renderUI({
      shiny::req(status())
      shiny::h4("Cutting")
    })
    output$counts <- shiny::renderTable({
      sel <- selecao()
      shiny::req(sel, nrow(sel) > 0)
      count(sel, site, species_folder) |>
        pivot_wider(names_from = species_folder, values_from = n,
                    values_fill = 0L)
    })
    output$inclusion <- shiny::renderTable({
      sel <- selecao()
      shiny::req(sel, nrow(sel) > 0, any(!is.na(sel$inclusion_prob)))
      sel |>
        summarise(n = n(), min = min(inclusion_prob, na.rm = TRUE),
                  median = stats::median(inclusion_prob, na.rm = TRUE),
                  max = max(inclusion_prob, na.rm = TRUE),
                  .by = species_folder) |>
        arrange(species_folder)
    }, digits = 3)
    output$cut_status <- shiny::renderTable({
      shiny::req(status())
      status()
    })
    cortes
  })
}

export_ui <- function(id, output_dir) {
  ns <- shiny::NS(id)
  shiny::sidebarLayout(
    shiny::sidebarPanel(
      width = 4,
      shiny::selectInput(ns("occasion_unit"), "Occasion",
                         c("file", "minute")),
      hint("The unit of time over which a species counts as detected or",
           "not at a site. Use the one of the clip extraction."),
      shiny::numericInput(ns("min_confidence"), "Minimum score", 0.1,
                          min = 0, max = 1, step = 0.05),
      hint("Predictions below this score are left out. Use the minimum",
           "score of the BirdNET run or higher."),
      shiny::textInput(ns("export_dir"), "Export folder",
                       file.path(output_dir, "occupancy")),
      hint("Where the occupancy tables are written."),
      shiny::checkboxInput(ns("overwrite"), "Overwrite an existing export"),
      hint("Replaces an earlier export in this folder."),
      shiny::actionButton(ns("export"), "Export", class = "btn-primary"),
      shiny::helpText("The score calibration is not in the app yet: call",
                      "export_occupancy_data() with `fit` for it.")
    ),
    shiny::mainPanel(
      width = 8,
      shiny::uiOutput(ns("notes")),
      shiny::tableOutput(ns("summary")),
      shiny::tableOutput(ns("tables"))
    )
  )
}

# Vereditos do app para a exportacao: consenso entre revisores e sem os
# clipes nao revisados
app_validation <- function(manifest, verdicts_file, clips_dir) {
  if (!file.exists(manifest) || !file.exists(verdicts_file)) return(NULL)
  v <- suppressMessages(app_verdicts(manifest, verdicts_file, clips_dir))
  v <- v[v$verdict != "not_reviewed", ]
  if (nrow(v) == 0) return(NULL)
  suppressMessages(consensus_verdicts(v))
}

export_server <- function(id, detections, output_dir, clips_dir,
                          verdicts_file, recordings = NULL,
                          classifier = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    resultado <- shiny::reactiveVal(NULL)
    notas <- shiny::reactiveVal(character())
    shiny::observeEvent(input$export, {
      validacao <- app_validation(file.path(output_dir, "clip_manifest.csv"),
                                  verdicts_file, clips_dir)
      r <- tryCatch(
        with_notes(export_occupancy_data(
          input$export_dir, detections, recordings = recordings,
          validation = validacao, occasion_unit = input$occasion_unit,
          min_confidence = input$min_confidence, classifier = classifier,
          overwrite = isTRUE(input$overwrite))),
        error = function(e) {
          list(value = NULL, notes = paste("Error:", conditionMessage(e)))
        })
      if (is.null(validacao)) {
        r$notes <- c(r$notes, "No reviewed clip yet: exported without the validation tables.")
      }
      notas(r$notes)
      resultado(r$value)
    })
    output$notes <- shiny::renderUI({
      n <- notas()
      if (length(n) == 0) return(NULL)
      shiny::div(class = "alert alert-info",
                 lapply(n, function(x) shiny::p(x)))
    })
    output$summary <- shiny::renderTable({
      r <- resultado()
      shiny::req(r)
      campo <- function(x) if (is.null(x)) NA_character_ else
        as.character(x)
      tibble(field = c("Schema", "Version", "Occasion", "Folder"),
             value = c(campo(r$schema$schema),
                       campo(r$schema$schema_version),
                       campo(r$schema$occasion_unit), input$export_dir))
    }, colnames = FALSE)
    output$tables <- shiny::renderTable({
      r <- resultado()
      shiny::req(r)
      tibble(table = names(r$tables),
             rows = vapply(r$tables, nrow, integer(1)))
    })
    resultado
  })
}
