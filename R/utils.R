# Funcoes auxiliares internas

# Converte caminhos do estilo Windows (N:\Arara\...) para barras normais,
# aplicando o remapeamento opcional de prefixo
remap_path <- function(caminho, de = NULL, para = NULL) {
  caminho <- str_replace_all(caminho, fixed("\\"), "/")
  if (!is.null(de) && !is.null(para)) {
    de <- str_replace_all(de, fixed("\\"), "/")
    caminho <- str_replace(caminho, fixed(de), para)
  }
  caminho
}

# Extrai data (AAAAMMDD) e hora (HH) do nome do arquivo de gravacao,
# assumindo o padrao <...>_AAAAMMDD_HHMMSS.<ext> dos gravadores
parse_date_hour <- function(nome_arquivo) {
  m <- str_match(nome_arquivo, "(\\d{8})_(\\d{6})")
  tibble(
    recording_date = m[, 2],
    recording_hour = str_sub(m[, 3], 1, 2)
  )
}

# Codigo curto da especie para nome de pasta: parte final do rotulo do
# classificador, ex. "Adenomera diptyx_ade-dip" -> "ade_dip"; se o rotulo
# ja for curto ("ade-dip"), funciona igual
folder_name <- function(species_code) {
  str_replace_all(str_extract(species_code, "[^_]+$"), "-", "_")
}

# Exige um pacote de Suggests
# Is a suggested package installed? (one place, so tests can mock it)
has_suggested <- function(pkg) {
  requireNamespace(pkg, quietly = TRUE)
}

require_suggested <- function(pkg, para) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Package '", pkg, "' is needed ", para, ". Install it with ",
         "install.packages(\"", pkg, "\").", call. = FALSE)
  }
}

# Sitio tirado do nome do arquivo: `pattern` e uma expressao regular com um
# grupo de captura, aplicada ao nome sem a pasta (ex. "^[^_]+_([^_]+)_" para
# Campinas_Campus01_20261003_074339.flac)
site_from_name <- function(paths, pattern) {
  if (!is.character(pattern) || length(pattern) != 1 || is.na(pattern) ||
      !nzchar(pattern)) {
    stop("`site_pattern` must be a single regular expression.",
         call. = FALSE)
  }
  nomes <- basename(str_replace_all(paths, fixed("\\"), "/"))
  m <- str_match(nomes, pattern)
  if (ncol(m) < 2) {
    stop("`site_pattern` needs a capture group around the site, e.g. ",
         "\"^[^_]+_([^_]+)_\".", call. = FALSE)
  }
  sitio <- m[, 2]
  falha <- is.na(sitio) | !nzchar(sitio)
  if (any(falha)) {
    stop(sum(falha), " file name(s) do not match `site_pattern` ", pattern,
         " (e.g. ", nomes[falha][1], ").", call. = FALSE)
  }
  sitio
}
