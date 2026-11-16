#' Read predictions and recordings from a pamDP data package
#'
#' Reads a data package in the pamDP format of pamflow (an adaptation of
#' Camtrap DP to passive acoustic monitoring) and returns the machine
#' predictions in the shape of [read_selection_tables()] and the list of
#' recordings in the shape of [list_recordings()], so that both can go to
#' [select_clips()], [export_occupancy_data()] and [run_app()].
#'
#' A pamDP package holds three tables: `deployments.csv` (one row per
#' recorder deployment, with its location), `media.csv` (one row per audio
#' file) and `observations.csv` (one row per classified event, with the
#' offsets `eventStart` and `eventEnd` in seconds from the start of the
#' audio file). When the folder has a `datapackage.json`, the paths of the
#' three tables are taken from its resources (`deployments`, `media`,
#' `observations`); otherwise the files are looked for by those names.
#'
#' **Predictions.** Observations of a classifier are kept: those with
#' `classificationMethod` equal to `"machine"` (or empty) and a
#' `classificationProbability`, of type `"animal"` when `observationType` is
#' given, with a `scientificName` and a `mediaID` found in `media.csv`.
#' Observations classified by people (`classificationMethod = "human"`) are
#' left out with a message: pamDP has no field that links a human
#' classification to the prediction it checks, so they cannot be read as
#' verdicts. The columns are mapped as follows:
#'
#' | pamDP | sheepdog |
#' |---|---|
#' | `classificationProbability` | `confidence` |
#' | `eventStart`, `eventEnd` | `begin_time`, `end_time`; `file_offset` = `eventStart` |
#' | `filePath` of the media | `begin_path` |
#' | `frequencyLow`, `frequencyHigh` | `low_freq`, `high_freq` |
#' | `scientificName` | `species_code`, see below |
#' | `site_column` of the deployment | `site` |
#'
#' sheepdog names the folder of a species after the part of `species_code`
#' after the last underscore, as in BirdNET labels
#' (`"Adenomera diptyx_ade-dip"` gives `ade_dip`). The scientific name
#' alone has no such part, so `species_code` is built as the scientific name
#' and its lower-case, hyphenated form: `"Boana raniceps"` becomes
#' `"Boana raniceps_boana-raniceps"`, whose folder is `boana_raniceps`.
#'
#' **Recordings.** Every row of `media.csv` is a recording, including the
#' ones without any prediction, which the occasions of the occupancy models
#' and `"random_recordings"` need. The table has `site` and `source_audio`
#' (the same path as `begin_path`), as [list_recordings()] does, plus
#' `media_id`, `deployment_id`, `timestamp` and `file_length` (seconds).
#'
#' **Dates and hours.** sheepdog takes the date and hour of a recording from
#' its file name (`YYYYMMDD_HHMMSS`), not from the `timestamp` of
#' `media.csv`. The files whose names do not carry them are reported;
#' rename them, or the nights and hours of the occasions will be missing.
#'
#' @param dir Folder of the data package.
#' @param site_column Column of `deployments.csv` that names the site:
#'   `"locationID"` (default), `"locationName"` or `"deploymentID"`.
#'   Deployments with this column empty take their `deploymentID`, with a
#'   message.
#' @param audio_root Optional folder that relative `filePath` values are
#'   resolved against (e.g. the folder of the audio files on this
#'   computer). `NULL` keeps `filePath` as it is. Paths that are absolute
#'   or URLs are never changed.
#'
#' @return A list with two tibbles: `predictions`, one row per prediction,
#'   with `site` first, the columns required by [select_clips()]
#'   (`begin_time`, `end_time`, `species_code`, `confidence`, `begin_path`,
#'   `file_offset`) and `observation_id`, `deployment_id`, `media_id`,
#'   `scientific_name`, `classified_by`, `low_freq` and `high_freq`; and
#'   `recordings`, one row per audio file.
#' @references
#' Betancourt, N., Toro-Gómez, M., Cañas, J., Barona-Cortés, E., et al.
#' (2026). pamflow: an open-source workflow for simplified passive acoustic
#' monitoring data analysis. *Methods in Ecology and Evolution*.
#' \doi{10.1111/2041-210x.70432}
#'
#' Bubnicki, J. W., Norton, B., Baskauf, S. J., Bruce, T., et al. (2024).
#' Camtrap DP: an open standard for the FAIR exchange and archiving of
#' camera trap data. *Remote Sensing in Ecology and Conservation*, 10(3),
#' 283-295. \doi{10.1002/rse2.374}
#' @seealso [read_selection_tables()], [list_recordings()],
#'   `vignette("organising-data")`.
#' @export
#' @examples
#' dp <- file.path(tempdir(), "pamdp")
#' dir.create(dp, showWarnings = FALSE)
#' utils::write.csv(data.frame(
#'   deploymentID = c("d1", "d2"), locationID = c("ARA", "BAI"),
#'   latitude = -20, longitude = -54,
#'   deploymentStart = "2021-10-01T18:00:00-04:00",
#'   deploymentEnd = "2021-10-02T06:00:00-04:00"),
#'   file.path(dp, "deployments.csv"), row.names = FALSE)
#' utils::write.csv(data.frame(
#'   mediaID = c("m1", "m2", "m3"), deploymentID = c("d1", "d1", "d2"),
#'   timestamp = "2021-10-01T19:00:00-04:00",
#'   filePath = c("ARA/ARA01_20211001_190000.wav",
#'                "ARA/ARA01_20211001_200000.wav",
#'                "BAI/BAI01_20211001_190000.wav"),
#'   filePublic = FALSE, fileMediatype = "audio/wav", sampleRate = 48000,
#'   bitDepth = 16, fileLength = 60, numChannels = 1),
#'   file.path(dp, "media.csv"), row.names = FALSE)
#' utils::write.csv(data.frame(
#'   observationID = c("o1", "o2", "o3"), deploymentID = c("d1", "d1", "d2"),
#'   mediaID = c("m1", "m1", "m3"), eventStart = c(3, 12, 30),
#'   eventEnd = c(6, 15, 33), observationLevel = "event",
#'   observationType = "animal", scientificName = "Boana raniceps",
#'   classificationMethod = "machine", classifiedBy = "BirdNET 2.4",
#'   classificationProbability = c(0.91, 0.42, 0.77)),
#'   file.path(dp, "observations.csv"), row.names = FALSE)
#' pam <- read_pamdp(dp, audio_root = "/Volumes/NAS/audio")
#' pam$predictions
#' pam$recordings
read_pamdp <- function(dir, site_column = "locationID", audio_root = NULL) {
  if (!is.character(dir) || length(dir) != 1 || !dir.exists(dir)) {
    stop("`dir` must be the folder of a pamDP data package.", call. = FALSE)
  }
  if (!is.character(site_column) || length(site_column) != 1) {
    stop("`site_column` must be a single column name.", call. = FALSE)
  }
  caminhos <- pamdp_paths(dir)
  ler <- function(x) {
    readr::read_csv(x, col_types = cols(.default = col_character()),
                    na = c("", "NA"), progress = FALSE)
  }
  dep <- ler(caminhos[["deployments"]])
  med <- ler(caminhos[["media"]])
  obs <- ler(caminhos[["observations"]])
  pamdp_require(dep, c("deploymentID"), "deployments.csv")
  pamdp_require(med, c("mediaID", "deploymentID", "filePath"), "media.csv")
  pamdp_require(obs, c("observationID", "deploymentID", "eventStart",
                       "eventEnd"), "observations.csv")
  if (!site_column %in% names(dep)) {
    stop("deployments.csv has no column `", site_column, "`. Columns: ",
         paste(names(dep), collapse = ", "), call. = FALSE)
  }

  sitio <- dep[[site_column]]
  vazio <- is.na(sitio) | !nzchar(sitio)
  if (any(vazio)) {
    message(sum(vazio), " deployment(s) without `", site_column,
            "` take their deploymentID as site.")
    sitio[vazio] <- dep$deploymentID[vazio]
  }
  sitios <- tibble(deploymentID = dep$deploymentID, site = sitio)

  med$source_audio <- pamdp_resolve(med$filePath, audio_root)
  semdep <- !med$deploymentID %in% sitios$deploymentID
  if (any(semdep)) {
    stop(sum(semdep), " media file(s) refer to deployments not in ",
         "deployments.csv (e.g. ", med$deploymentID[semdep][1], ").",
         call. = FALSE)
  }
  num <- function(x) suppressWarnings(as.numeric(x))
  med$momento <- if ("timestamp" %in% names(med)) med[["timestamp"]] else NA_character_
  med$duracao <- if ("fileLength" %in% names(med)) num(med[["fileLength"]]) else NA_real_
  gravacoes <- med |>
    left_join(sitios, by = "deploymentID") |>
    transmute(site, source_audio, media_id = mediaID,
              deployment_id = deploymentID, timestamp = momento,
              file_length = duracao) |>
    arrange(site, source_audio)

  col <- function(nome) if (nome %in% names(obs)) obs[[nome]] else rep(NA_character_, nrow(obs))
  metodo <- col("classificationMethod")
  humanas <- !is.na(metodo) & metodo == "human"
  if (any(humanas)) {
    message(sum(humanas), " observation(s) classified by people left out: ",
            "pamDP does not link them to the predictions they check.")
  }
  prob <- num(col("classificationProbability"))
  tipo <- col("observationType")
  nome <- col("scientificName")
  manter <- !humanas & (is.na(metodo) | metodo == "machine") & !is.na(prob) &
    (is.na(tipo) | tipo == "animal") & !is.na(nome) & nzchar(nome)
  outras <- sum(!humanas & !manter)
  if (outras > 0) {
    message(outras, " other observation(s) left out (not of a classifier, ",
            "without classificationProbability or scientificName, or not ",
            "of type \"animal\").")
  }
  obs <- obs[manter, , drop = FALSE]
  sem_midia <- is.na(obs$mediaID) | !obs$mediaID %in% med$mediaID
  if (any(sem_midia)) {
    message(sum(sem_midia), " prediction(s) without a media file in ",
            "media.csv left out.")
    obs <- obs[!sem_midia, , drop = FALSE]
  }
  if (nrow(obs) == 0) stop("No machine prediction found in ",
                           caminhos[["observations"]], ".", call. = FALSE)

  col <- function(nome) if (nome %in% names(obs)) obs[[nome]] else rep(NA_character_, nrow(obs))
  nome <- str_squish(obs$scientificName)
  predicoes <- tibble(
    observation_id = obs$observationID, deployment_id = obs$deploymentID,
    media_id = obs$mediaID,
    begin_time = num(obs$eventStart), end_time = num(obs$eventEnd),
    low_freq = num(col("frequencyLow")), high_freq = num(col("frequencyHigh")),
    scientific_name = nome,
    species_code = paste0(nome, "_",
                          str_replace_all(str_to_lower(nome), "\\s+", "-")),
    confidence = num(obs$classificationProbability),
    classified_by = col("classifiedBy")) |>
    left_join(select(med, media_id = mediaID, begin_path = source_audio,
                     deployment_media = deploymentID), by = "media_id")
  if (any(predicoes$deployment_media != predicoes$deployment_id)) {
    warning("Some predictions have a deploymentID different from that of ",
            "their media file; the site follows the media file.",
            call. = FALSE)
  }
  predicoes <- predicoes |>
    left_join(rename(sitios, deployment_media = deploymentID),
              by = "deployment_media") |>
    mutate(file_offset = begin_time) |>
    select(site, begin_time, end_time, low_freq, high_freq, species_code,
           confidence, begin_path, file_offset, observation_id,
           deployment_id = deployment_media, media_id, scientific_name,
           classified_by)
  ruins <- is.na(predicoes$begin_time) | is.na(predicoes$end_time) |
    predicoes$confidence < 0 | predicoes$confidence > 1
  if (any(ruins)) {
    stop(sum(ruins), " prediction(s) with missing eventStart/eventEnd or ",
         "classificationProbability outside 0-1 (e.g. observationID ",
         predicoes$observation_id[ruins][1], ").", call. = FALSE)
  }

  sem_data <- is.na(parse_date_hour(basename(gravacoes$source_audio))$recording_date)
  if (any(sem_data)) {
    message(sum(sem_data), " of ", nrow(gravacoes), " audio file name(s) ",
            "lack the date and time as YYYYMMDD_HHMMSS (e.g. ",
            basename(gravacoes$source_audio[sem_data][1]), "); sheepdog ",
            "reads them from the file name, not from `timestamp`.")
  }
  message(nrow(predicoes), " predictions of ",
          n_distinct(predicoes$species_code), " species read from ",
          n_distinct(predicoes$site), " site(s); ", nrow(gravacoes),
          " recordings.")
  list(predictions = predicoes, recordings = gravacoes)
}

# Caminhos das tres tabelas: pelos recursos do datapackage.json, se houver,
# senao pelos nomes padrao
pamdp_paths <- function(dir) {
  padrao <- c(deployments = "deployments.csv", media = "media.csv",
              observations = "observations.csv")
  caminhos <- file.path(dir, padrao)
  names(caminhos) <- names(padrao)
  dp <- file.path(dir, "datapackage.json")
  if (file.exists(dp)) {
    pacote <- jsonlite::read_json(dp)
    for (r in pacote$resources) {
      if (!is.null(r$name) && r$name %in% names(padrao) &&
          is.character(r$path) && length(r$path) == 1) {
        caminhos[[r$name]] <- file.path(dir, r$path)
      }
    }
  }
  falta <- !file.exists(caminhos)
  if (any(falta)) {
    stop("pamDP table(s) not found: ",
         paste(caminhos[falta], collapse = ", "), call. = FALSE)
  }
  caminhos
}

pamdp_require <- function(tb, colunas, arquivo) {
  falta <- setdiff(colunas, names(tb))
  if (length(falta) > 0) {
    stop(arquivo, " lacks the column(s): ", paste(falta, collapse = ", "),
         call. = FALSE)
  }
}

# filePath relativo resolvido contra audio_root; absolutos e URLs ficam
pamdp_resolve <- function(caminho, raiz) {
  caminho <- str_replace_all(caminho, fixed("\\"), "/")
  if (is.null(raiz)) return(caminho)
  absoluto <- str_detect(caminho, "^(/|[A-Za-z]:/|[A-Za-z][A-Za-z0-9+.-]*://)")
  raiz <- str_remove(str_replace_all(raiz, fixed("\\"), "/"), "/+$")
  ifelse(absoluto, caminho, paste0(raiz, "/", str_remove(caminho, "^\\./")))
}
