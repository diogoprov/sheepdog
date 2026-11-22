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
#' @param dir Character scalar, path to the folder of the data package.
#' @param site_column Character scalar, column of `deployments.csv` that
#'   names the site:
#'   `"locationID"` (default), `"locationName"` or `"deploymentID"`.
#'   Deployments with this column empty take their `deploymentID`, with a
#'   message.
#' @param audio_root `NULL` or character scalar, folder that relative
#'   `filePath` values are
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
  check_string(audio_root, "audio_root", null_ok = TRUE)
  paths <- pamdp_paths(dir)
  read_chr <- function(x) {
    readr::read_csv(x, col_types = cols(.default = col_character()),
                    na = c("", "NA"), progress = FALSE)
  }
  dep <- read_chr(paths[["deployments"]])
  med <- read_chr(paths[["media"]])
  obs <- read_chr(paths[["observations"]])
  pamdp_require(dep, c("deploymentID"), "deployments.csv")
  pamdp_require(med, c("mediaID", "deploymentID", "filePath"), "media.csv")
  pamdp_require(obs, c("observationID", "deploymentID", "eventStart",
                       "eventEnd"), "observations.csv")
  if (!site_column %in% names(dep)) {
    stop("deployments.csv has no column `", site_column, "`. Columns: ",
         paste(names(dep), collapse = ", "), call. = FALSE)
  }

  site_id <- dep[[site_column]]
  empty <- is.na(site_id) | !nzchar(site_id)
  if (any(empty)) {
    message(sum(empty), " deployment(s) without `", site_column,
            "` take their deploymentID as site.")
    site_id[empty] <- dep$deploymentID[empty]
  }
  sites <- tibble(deploymentID = dep$deploymentID, site = site_id)

  med$source_audio <- pamdp_resolve(med$filePath, audio_root)
  no_dep <- !med$deploymentID %in% sites$deploymentID
  if (any(no_dep)) {
    stop(sum(no_dep), " media file(s) refer to deployments not in ",
         "deployments.csv (e.g. ", med$deploymentID[no_dep][1], ").",
         call. = FALSE)
  }
  num <- function(x) suppressWarnings(as.numeric(x))
  med$.ts <- if ("timestamp" %in% names(med)) med[["timestamp"]] else NA_character_
  med$.len <- if ("fileLength" %in% names(med)) num(med[["fileLength"]]) else NA_real_
  recordings <- med |>
    left_join(sites, by = "deploymentID") |>
    transmute(site, source_audio, media_id = mediaID,
              deployment_id = deploymentID, timestamp = .ts,
              file_length = .len) |>
    arrange(site, source_audio)

  col <- function(name) if (name %in% names(obs)) obs[[name]] else rep(NA_character_, nrow(obs))
  method <- col("classificationMethod")
  human <- !is.na(method) & method == "human"
  if (any(human)) {
    message(sum(human), " observation(s) classified by people left out: ",
            "pamDP does not link them to the predictions they check.")
  }
  prob <- num(col("classificationProbability"))
  type <- col("observationType")
  sci_name <- col("scientificName")
  keep <- !human & (is.na(method) | method == "machine") & !is.na(prob) &
    (is.na(type) | type == "animal") & !is.na(sci_name) & nzchar(sci_name)
  others <- sum(!human & !keep)
  if (others > 0) {
    message(others, " other observation(s) left out (not of a classifier, ",
            "without classificationProbability or scientificName, or not ",
            "of type \"animal\").")
  }
  obs <- obs[keep, , drop = FALSE]
  no_media <- is.na(obs$mediaID) | !obs$mediaID %in% med$mediaID
  if (any(no_media)) {
    message(sum(no_media), " prediction(s) without a media file in ",
            "media.csv left out.")
    obs <- obs[!no_media, , drop = FALSE]
  }
  if (nrow(obs) == 0) stop("No machine prediction found in ",
                           paths[["observations"]], ".", call. = FALSE)

  col <- function(name) if (name %in% names(obs)) obs[[name]] else rep(NA_character_, nrow(obs))
  sci_name <- str_squish(obs$scientificName)
  predictions <- tibble(
    observation_id = obs$observationID, deployment_id = obs$deploymentID,
    media_id = obs$mediaID,
    begin_time = num(obs$eventStart), end_time = num(obs$eventEnd),
    low_freq = num(col("frequencyLow")), high_freq = num(col("frequencyHigh")),
    scientific_name = sci_name,
    species_code = paste0(sci_name, "_",
                          str_replace_all(str_to_lower(sci_name), "\\s+", "-")),
    confidence = num(obs$classificationProbability),
    classified_by = col("classifiedBy")) |>
    left_join(select(med, media_id = mediaID, begin_path = source_audio,
                     deployment_media = deploymentID), by = "media_id")
  if (any(predictions$deployment_media != predictions$deployment_id)) {
    warning("Some predictions have a deploymentID different from that of ",
            "their media file; the site follows the media file.",
            call. = FALSE)
  }
  predictions <- predictions |>
    left_join(rename(sites, deployment_media = deploymentID),
              by = "deployment_media") |>
    mutate(file_offset = begin_time) |>
    select(site, begin_time, end_time, low_freq, high_freq, species_code,
           confidence, begin_path, file_offset, observation_id,
           deployment_id = deployment_media, media_id, scientific_name,
           classified_by)
  bad <- is.na(predictions$begin_time) | is.na(predictions$end_time) |
    predictions$confidence < 0 | predictions$confidence > 1
  if (any(bad)) {
    stop(sum(bad), " prediction(s) with missing eventStart/eventEnd or ",
         "classificationProbability outside 0-1 (e.g. observationID ",
         predictions$observation_id[bad][1], ").", call. = FALSE)
  }

  no_date <- is.na(parse_date_hour(basename(recordings$source_audio))$recording_date)
  if (any(no_date)) {
    message(sum(no_date), " of ", nrow(recordings), " audio file name(s) ",
            "lack the date and time as YYYYMMDD_HHMMSS (e.g. ",
            basename(recordings$source_audio[no_date][1]), "); sheepdog ",
            "reads them from the file name, not from `timestamp`.")
  }
  message(nrow(predictions), " predictions of ",
          n_distinct(predictions$species_code), " species read from ",
          n_distinct(predictions$site), " site(s); ", nrow(recordings),
          " recordings.")
  list(predictions = predictions, recordings = recordings)
}

#' Paths of the three pamDP tables
#'
#' Takes the paths from the resources of `datapackage.json` when there is
#' one, otherwise the default file names; errors when a table is missing.
#'
#' @param dir Character scalar, folder of the data package.
#' @return Named character vector of length 3 (`deployments`, `media`,
#'   `observations`) with the table paths.
#' @noRd
pamdp_paths <- function(dir) {
  defaults <- c(deployments = "deployments.csv", media = "media.csv",
                observations = "observations.csv")
  paths <- file.path(dir, defaults)
  names(paths) <- names(defaults)
  dp <- file.path(dir, "datapackage.json")
  if (file.exists(dp)) {
    pkg <- jsonlite::read_json(dp)
    for (r in pkg$resources) {
      if (!is.null(r$name) && r$name %in% names(defaults) &&
          is.character(r$path) && length(r$path) == 1) {
        paths[[r$name]] <- file.path(dir, r$path)
      }
    }
  }
  absent <- !file.exists(paths)
  if (any(absent)) {
    stop("pamDP table(s) not found: ",
         paste(paths[absent], collapse = ", "), call. = FALSE)
  }
  paths
}

#' Check that a pamDP table has the required columns
#'
#' @param tb A data frame read from a pamDP table.
#' @param cols Character vector of required column names.
#' @param file Character scalar, name of the table for the error message.
#' @return Called for its side effect: errors when a column is missing.
#' @noRd
pamdp_require <- function(tb, cols, file) {
  absent <- setdiff(cols, names(tb))
  if (length(absent) > 0) {
    stop(file, " lacks the column(s): ", paste(absent, collapse = ", "),
         call. = FALSE)
  }
}

#' Resolve relative pamDP file paths against an audio root
#'
#' Backslashes become slashes; absolute paths and URLs are kept as they are.
#'
#' @param path Character vector of `filePath` values.
#' @param root Character scalar or `NULL`, folder the relative paths are
#'   resolved against; `NULL` keeps the paths.
#' @return Character vector of paths, same length as `path`.
#' @noRd
pamdp_resolve <- function(path, root) {
  path <- str_replace_all(path, fixed("\\"), "/")
  if (is.null(root)) return(path)
  absolute <- str_detect(path, "^(/|[A-Za-z]:/|[A-Za-z][A-Za-z0-9+.-]*://)")
  root <- str_remove(str_replace_all(root, fixed("\\"), "/"), "/+$")
  ifelse(absolute, path, paste0(root, "/", str_remove(path, "^\\./")))
}
