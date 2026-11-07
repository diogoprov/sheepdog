# =============================================================================
# schematic_icons.R
#
# Icones em SVG dos esquemas do indice de referencia: clipe, fones, pasta,
# revisor, tabela, curva. Os desenhos seguem os de Larissa S. M. Sugai, com a
# paleta de diagram_pipeline.R e sem caixas em volta.
# Dependencia: install.packages("rsvg")
# =============================================================================

tinta <- "#2c3e50"; cinza <- "#7f8c99"; azul <- "#1f5c8b"; azul_claro <- "#d9e9f8"
verde <- "#1e6b3a"; verde_claro <- "#d9f2e0"
vermelho <- "#a33a3a"; vermelho_claro <- "#f6dcdc"
fonte <- "Helvetica, Arial, sans-serif"

svg_text <- function(x, y, s, size = 13, fill = tinta, anchor = "middle",
                     family = fonte) {
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;", s, fixed = TRUE)
  sprintf('<text x="%.1f" y="%.1f" font-family="%s" font-size="%s" fill="%s" text-anchor="%s">%s</text>',
          x, y, family, size, fill, anchor, s)
}

# Rotulo em ate tres linhas, centrado; a primeira e a funcao
svg_caption <- function(x, y, titulo, linhas = character()) {
  paste(c(svg_text(x, y, titulo, 13, tinta),
          vapply(seq_along(linhas), \(i) svg_text(x, y + 17 * i, linhas[i], 11.5, cinza), "")),
        collapse = "\n")
}

svg_arrow <- function(x1, y1, x2, y2, dash = FALSE) {
  d <- if (dash) ' stroke-dasharray="5 4"' else ""
  ang <- atan2(y2 - y1, x2 - x1); a <- 8
  p1 <- c(x2 - a * cos(ang - 0.4), y2 - a * sin(ang - 0.4))
  p2 <- c(x2 - a * cos(ang + 0.4), y2 - a * sin(ang + 0.4))
  sprintf('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="1.3"%s/><polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="%s"/>',
          x1, y1, x2, y2, cinza, d, x2, y2, p1[1], p1[2], p2[1], p2[2], cinza)
}

# Clipe: forma de onda dentro de um retangulo arredondado
icon_clip <- function(x, y, w = 44, h = 26, stroke = azul, fill = "#ffffff",
                      crossed = FALSE) {
  n <- 9
  alt <- c(.25, .6, .35, .9, .5, .75, .3, .55, .2)
  xs <- x + w * (seq_len(n) + 0.5) / (n + 2)
  barras <- paste(sprintf(
    '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="1.6" stroke-linecap="round"/>',
    xs, y + h / 2 - alt * h * .36, xs, y + h / 2 + alt * h * .36, stroke), collapse = "")
  cruz <- if (crossed) sprintf(
    '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="2"/><line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="2"/>',
    x - 3, y - 3, x + w + 3, y + h + 3, vermelho, x - 3, y + h + 3, x + w + 3, y - 3, vermelho) else ""
  sprintf('<rect x="%.1f" y="%.1f" width="%s" height="%s" rx="5" fill="%s" stroke="%s" stroke-width="1.3"/>%s%s',
          x, y, w, h, fill, stroke, barras, cruz)
}

icon_headphones <- function(x, y, s = 1, stroke = azul) {
  sprintf('<g transform="translate(%.1f %.1f) scale(%s)"><path d="M6 34 V24 a19 19 0 0 1 38 0 V34" fill="none" stroke="%s" stroke-width="3.2"/><rect x="1" y="30" width="10" height="17" rx="4" fill="%s"/><rect x="39" y="30" width="10" height="17" rx="4" fill="%s"/></g>',
          x, y, s, stroke, stroke, stroke)
}

icon_folder <- function(x, y, w = 46, stroke = azul, fill = azul_claro) {
  h <- w * .72
  sprintf('<path d="M%.1f %.1f h%.1f l%.1f %.1f h%.1f v%.1f h%.1f z" fill="%s" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>',
          x, y, w * .38, w * .1, h * .16, w * .52, h * .84, -w, fill, stroke)
}

icon_person <- function(x, y, s = 1, stroke = azul, fill = azul_claro) {
  sprintf('<g transform="translate(%.1f %.1f) scale(%s)"><circle cx="20" cy="12" r="10" fill="%s" stroke="%s" stroke-width="1.5"/><path d="M2 46 a18 18 0 0 1 36 0 z" fill="%s" stroke="%s" stroke-width="1.5"/></g>',
          x, y, s, fill, stroke, fill, stroke)
}

icon_table <- function(x, y, w = 48, h = 36, stroke = azul) {
  linhas <- paste(sprintf('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s"/>',
                          x + 6, y + h * c(.42, .62, .82), x + w - 6, y + h * c(.42, .62, .82), stroke), collapse = "")
  sprintf('<rect x="%.1f" y="%.1f" width="%s" height="%s" rx="3" fill="#ffffff" stroke="%s" stroke-width="1.3"/><rect x="%.1f" y="%.1f" width="%s" height="%.1f" fill="%s"/>%s',
          x, y, w, h, stroke, x + .7, y + .7, w - 1.4, h * .24, azul_claro, linhas)
}

icon_loss <- function(x, y, w = 56, h = 38, stroke = azul) {
  sprintf('<path d="M%.1f %.1f V%.1f H%.1f" fill="none" stroke="%s"/><path d="M%.1f %.1f C %.1f %.1f, %.1f %.1f, %.1f %.1f" fill="none" stroke="%s" stroke-width="2"/>',
          x, y, y + h, x + w, cinza, x + 3, y + 3, x + w * .25, y + h * .75, x + w * .55, y + h * .85, x + w - 2, y + h * .88, stroke)
}

save_schematic <- function(body, name, w, h, scale = 2) {
  svg <- sprintf('<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 %s %s"><rect width="%s" height="%s" fill="white"/>%s</svg>',
                 w, h, w, h, w, h, paste(body, collapse = "\n"))
  dir.create("pkgdown/assets/figures", recursive = TRUE, showWarnings = FALSE)
  arquivo <- file.path("pkgdown/assets/figures", paste0(name, ".png"))
  rsvg::rsvg_png(charToRaw(svg), arquivo, width = w * scale)
  message("Schematic written to ", arquivo)
}

# Pecas dos esquemas de dados ------------------------------------------------
ocre <- "#8a5a00"; ocre_claro <- "#fceecf"; claro <- "#d9dee3"

svg_rect <- function(x, y, w, h, fill = "#ffffff", stroke = "none", rx = 2) {
  sprintf('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%s" fill="%s" stroke="%s"/>',
          x, y, w, h, rx, fill, stroke)
}
svg_dot <- function(x, y, r = 3, fill = azul, stroke = "none") {
  sprintf('<circle cx="%.1f" cy="%.1f" r="%s" fill="%s" stroke="%s"/>', x, y, r, fill, stroke)
}
svg_line <- function(x1, y1, x2, y2, stroke = cinza, width = 1, dash = NULL) {
  d <- if (is.null(dash)) "" else sprintf(' stroke-dasharray="%s"', dash)
  sprintf('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="%s"%s/>',
          x1, y1, x2, y2, stroke, width, d)
}
# Curva logistica entre x0 e x1, de baixo (y0) para cima (y1)
svg_logistic <- function(x0, x1, y0, y1, centro = 0.5, k = 9, stroke = ocre,
                         width = 2.2, dash = NULL) {
  t <- seq(0, 1, length.out = 60)
  px <- x0 + t * (x1 - x0)
  py <- y0 + plogis(k * (t - centro)) * (y1 - y0)
  d <- if (is.null(dash)) "" else sprintf(' stroke-dasharray="%s"', dash)
  sprintf('<polyline points="%s" fill="none" stroke="%s" stroke-width="%s"%s/>',
          paste(sprintf("%.1f,%.1f", px, py), collapse = " "), stroke, width, d)
}
# Grade de celulas: on e uma matriz logica ou de intensidades entre 0 e 1
svg_grid <- function(x, y, on, cell = 13, gap = 2, cor = azul) {
  out <- character()
  for (i in seq_len(nrow(on))) for (j in seq_len(ncol(on))) {
    v <- as.numeric(on[i, j])
    out <- c(out, sprintf(
      '<rect x="%.1f" y="%.1f" width="%s" height="%s" rx="2" fill="%s" fill-opacity="%.2f"/>',
      x + (j - 1) * (cell + gap), y + (i - 1) * (cell + gap), cell, cell,
      if (v > 0) cor else claro, if (v > 0) max(v, 0.2) else 0.7))
  }
  paste(out, collapse = "")
}
