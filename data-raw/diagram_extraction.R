# =============================================================================
# diagram_extraction.R
#
# Fluxograma (DiagrammeR) de extract_validation_clips(): da
# BirdNET_SelectionTable.txt de cada local ate os pacotes de clipes prontos
# para a revisao manual no BirdNET GUI.
#
# Uso: rode o script inteiro a partir da raiz do repositorio; o diagrama
# abre no Viewer do RStudio e e exportado para
# man/figures/extraction_flow.png / .svg.
# Dependencias: install.packages(c("DiagrammeR", "DiagrammeRsvg", "rsvg"))
# =============================================================================

library(DiagrammeR)

fluxo <- grViz('
digraph extraction {

  graph [rankdir = TB, fontname = "Helvetica", fontsize = 13,
         nodesep = 0.45, ranksep = 0.55, bgcolor = "white",
         label = "extract_validation_clips(): from BirdNET to validation packages",
         labelloc = "t", fontcolor = "#2c3e50"]

  node [fontname = "Helvetica", fontsize = 12, style = "filled,rounded",
        shape = box, penwidth = 1.1, color = "#8aa5b8",
        margin = "0.22,0.12"]
  edge [fontname = "Helvetica", fontsize = 10.5, color = "#7f8c99",
        fontcolor = "#5d6b78", arrowsize = 0.8]

  /* ---------------- ENTRADA ---------------- */
  subgraph cluster_entrada {
    label = "Input"
    fontcolor = "#1f5c8b"; color = "#bcd4e6"; style = "rounded"
    bgcolor = "#eef5fb"

    tabelas [label = "BirdNET_SelectionTable.txt\none per site (folder = site, or\nsite_pattern on the file name),\npredictions on every recording",
             shape = note, fillcolor = "#ffffff"]
    audios  [label = "Recordings\n..._YYYYMMDD_HHMMSS (.wav, .flac, .mp3)\n(Begin Path column)",
             shape = note, fillcolor = "#ffffff"]
  }

  /* ---------------- SELECAO ---------------- */
  subgraph cluster_selecao {
    label = "read_selection_tables() and select_clips(): no clip is cut"
    fontcolor = "#8a5a00"; color = "#ecd9b0"; style = "rounded"
    bgcolor = "#fdf6e9"

    ler      [label = "read_selection_tables()\nstandardised columns,\nsite = folder or site_pattern",
              fillcolor = "#fceecf"]
    remap    [label = "Remap paths (optional)\nremap_from / remap_to",
              fillcolor = "#fceecf"]
    filtros  [label = "Date and hour from the file name;\nfilters: sites, species, hour window,\nalternate days, date window",
              fillcolor = "#fceecf"]
    modo     [label = "sampling_mode", shape = diamond,
              style = "filled", fillcolor = "#f9e3ae", margin = "0.12,0.08"]
    top      [label = "\\"top\\"\nn_top highest confidence per\nsite x species x night x hour",
              fillcolor = "#f9e3ae"]
    det      [label = "\\"random_detections\\"\nrandom occasions with a detection\n>= threshold; all their detections;\ndrawn within site x species x strata:\nnight x hour, night, hour, week, month,\nown columns or covariate_bins()",
              fillcolor = "#f9e3ae"]
    rec      [label = "\\"random_recordings\\"\nrandom recordings (or minutes)\namong all recorded",
              fillcolor = "#f9e3ae"]
    bands    [label = "\\"score_bands\\"\nn_top random clips per\nsite x species x strata x score band\n(score_breaks); for thresholds and\ncalibration, not for crywolf",
              fillcolor = "#f9e3ae"]
    meta     [label = "target_total / max_per_species\nbalanced by species (and hour)",
              fillcolor = "#fceecf"]
  }

  lista [label = "list_recordings()\nevery recording made,\nwith or without predictions\n(recordings =)",
         shape = note, fillcolor = "#ffffff"]

  bins [label = "covariate_bins()\nbins of a night or occasion covariate\n(covariates =)",
        shape = note, fillcolor = "#ffffff"]

  /* ---------------- CORTE ---------------- */
  subgraph cluster_corte {
    label = "cut_clips() and pack_clips()"
    fontcolor = "#7a2e2e"; color = "#e6c3c3"; style = "rounded"
    bgcolor = "#fdf0f0"

    simular [label = "simulate = TRUE?", shape = diamond,
             style = "filled", fillcolor = "#f3e8fa", color = "#b393c9",
             margin = "0.12,0.08"]
    cortar [label = "Cut each clip with av (ffmpeg)\nstart = File Offset (s)\n(existing clips are skipped)",
            fillcolor = "#f9dcdc"]
    pastas [label = "One folder per species\nclips/<species_folder>/<clip_file>",
            fillcolor = "#f9dcdc"]
    zips   [label = "One zip per species\npackages/<species_folder>.zip",
            fillcolor = "#f9dcdc"]
  }

  manifesto [label = "clip_manifest.csv\nsite, species_code, night, recording_hour, confidence,\nclip_file, clip_start, clip_end, source_audio, status,\nsampling_mode, occasion_id, n_detections_occasion,\ninclusion_prob, ...",
             shape = note, fillcolor = "#ffffff"]

  gui [label = "Manual review in the BirdNET GUI or run_app()\n> post_validation()",
       fillcolor = "#dff0d8", color = "#7cae7c", penwidth = 1.4]

  /* ---------------- FLUXO ---------------- */
  tabelas  -> ler
  ler      -> remap
  remap    -> filtros
  filtros  -> modo
  modo     -> top
  modo     -> det
  modo     -> rec
  modo     -> bands
  bins     -> det       [style = dashed]
  lista    -> rec       [style = dashed]
  top      -> meta
  det      -> meta
  rec      -> simular
  bands    -> simular
  meta     -> simular
  simular  -> cortar    [label = " no"]
  simular  -> manifesto [label = " yes: manifest only,\n no audio cut, no zip", style = dashed]
  audios   -> cortar    [label = " source audio", style = dashed]
  cortar   -> pastas
  pastas   -> manifesto
  pastas   -> zips      [label = " make_zip = TRUE"]
  zips     -> gui
  manifesto -> gui [style = dashed]
}
')

fluxo  # abre no Viewer

svg_txt <- DiagrammeRsvg::export_svg(fluxo)
rsvg::rsvg_png(charToRaw(svg_txt), "man/figures/extraction_flow.png", width = 2400)
rsvg::rsvg_svg(charToRaw(svg_txt), "man/figures/extraction_flow.svg")
message("Diagram written to man/figures/extraction_flow.png / .svg")
