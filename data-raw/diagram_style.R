# =============================================================================
# diagram_style.R
#
# Estilo comum dos diagramas por estagio do indice de referencia (o mesmo de
# diagram_pipeline.R e diagram_extraction.R) e a funcao que os salva. Os PNGs
# vao para pkgdown/assets/figures/, fora do pacote construido, porque so o
# site os usa.
# Dependencias: install.packages(c("DiagrammeR", "DiagrammeRsvg", "rsvg"))
# =============================================================================

diagram_header <- function(title, rankdir = "TB") {
  sprintf('
  graph [rankdir = %s, fontname = "Helvetica", fontsize = 13,
         nodesep = 0.35, ranksep = 0.42, bgcolor = "white",
         label = "%s", labelloc = "t", fontcolor = "#2c3e50"]
  node [fontname = "Helvetica", fontsize = 11.5, style = "filled,rounded",
        shape = box, penwidth = 1.1, color = "#8aa5b8", margin = "0.2,0.11"]
  edge [fontname = "Helvetica", fontsize = 10, color = "#7f8c99",
        fontcolor = "#5d6b78", arrowsize = 0.8]
', rankdir, title)
}

# Cores por estagio, como em diagram_pipeline.R
stage_cluster <- function(stage) {
  switch(stage,
    s1  = 'fontcolor = "#1f5c8b"; color = "#bcd4e6"; style = "rounded"; bgcolor = "#eef5fb"; node [fillcolor = "#d9e9f8"]',
    s2  = 'fontcolor = "#8a5a00"; color = "#ecd9b0"; style = "rounded"; bgcolor = "#fdf6e9"; node [fillcolor = "#fceecf"]',
    s3  = 'fontcolor = "#1e6b3a"; color = "#bcdcc6"; style = "rounded"; bgcolor = "#eefaf1"; node [fillcolor = "#d9f2e0"]',
    occ = 'fontcolor = "#5e3a7a"; color = "#d6c3e6"; style = "rounded"; bgcolor = "#f8f2fc"; node [fillcolor = "#efe2f8"]')
}

save_diagram <- function(dot, name, width = 1800) {
  fluxo <- DiagrammeR::grViz(dot)
  dir.create("pkgdown/assets/figures", recursive = TRUE, showWarnings = FALSE)
  arquivo <- file.path("pkgdown/assets/figures", paste0(name, ".png"))
  rsvg::rsvg_png(charToRaw(DiagrammeRsvg::export_svg(fluxo)), arquivo,
                 width = width)
  message("Diagram written to ", arquivo)
  invisible(fluxo)
}
