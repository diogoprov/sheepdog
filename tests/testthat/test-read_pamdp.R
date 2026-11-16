# read_pamdp(): predicoes e gravacoes de um pacote pamDP

pamdp_fixture <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  utils::write.csv(data.frame(
    deploymentID = c("d1", "d2", "d3"), locationID = c("ARA", NA, "CAP"),
    latitude = -20, longitude = -54,
    deploymentStart = "2021-10-01T18:00:00-04:00",
    deploymentEnd = "2021-10-02T06:00:00-04:00"),
    file.path(dir, "deployments.csv"), row.names = FALSE)
  utils::write.csv(data.frame(
    mediaID = c("m1", "m2", "m3", "m4"),
    deploymentID = c("d1", "d1", "d2", "d3"),
    timestamp = "2021-10-01T19:00:00-04:00",
    filePath = c("ARA/ARA01_20211001_190000.wav",
                 "ARA/ARA01_20211001_200000.wav",
                 "/abs/BAI01_20211001_190000.wav",
                 "CAP/sem_data.wav"),
    filePublic = FALSE, fileMediatype = "audio/wav", sampleRate = 48000,
    bitDepth = 16, fileLength = c(60, 60, 60, 30), numChannels = 1),
    file.path(dir, "media.csv"), row.names = FALSE)
  utils::write.csv(data.frame(
    observationID = paste0("o", 1:7),
    deploymentID = c("d1", "d1", "d2", "d1", "d1", "d1", "d1"),
    mediaID = c("m1", "m1", "m3", "m1", "m2", "m9", "m2"),
    eventStart = c(3, 12, 30, 3, 0, 1, 5),
    eventEnd = c(6, 15, 33, 6, 60, 4, 8),
    frequencyLow = c(1000, NA, 800, 1000, NA, NA, NA),
    frequencyHigh = c(4000, NA, 3000, 4000, NA, NA, NA),
    observationLevel = c(rep("event", 4), "media", "event", "event"),
    observationType = c("animal", "animal", "animal", "animal", "rain",
                        "animal", "animal"),
    scientificName = c("Boana raniceps", "Boana  raniceps",
                       "Physalaemus cuvieri", "Boana raniceps", NA,
                       "Boana raniceps", "Boana raniceps"),
    classificationMethod = c("machine", "machine", NA, "human", "machine",
                             "machine", "machine"),
    classifiedBy = c("BirdNET 2.4", "BirdNET 2.4", "BirdNET 2.4", "LS",
                     "BirdNET 2.4", "BirdNET 2.4", "BirdNET 2.4"),
    classificationProbability = c(0.91, 0.42, 0.77, NA, 0.6, 0.5, 0.33)),
    file.path(dir, "observations.csv"), row.names = FALSE)
  dir
}

test_that("machine predictions are read in the shape of selection tables", {
  dp <- pamdp_fixture()
  expect_message(pam <- read_pamdp(dp, audio_root = "/Volumes/NAS/audio/"),
                 "classified by people")
  p <- pam$predictions
  expect_equal(p$observation_id, c("o1", "o2", "o3", "o7"))
  expect_true(all(c("site", "begin_time", "end_time", "species_code",
                    "confidence", "begin_path", "file_offset") %in% names(p)))
  expect_identical(names(p)[1], "site")
  # local vazio pega o deploymentID
  expect_equal(p$site, c("ARA", "ARA", "d2", "ARA"))
  expect_equal(p$species_code[1:3],
               c("Boana raniceps_boana-raniceps",
                 "Boana raniceps_boana-raniceps",
                 "Physalaemus cuvieri_physalaemus-cuvieri"))
  expect_equal(sheepdog:::folder_name(p$species_code[3]),
               "physalaemus_cuvieri")
  expect_equal(p$file_offset, p$begin_time)
  expect_equal(p$confidence, c(0.91, 0.42, 0.77, 0.33))
  expect_equal(p$low_freq[1], 1000)
  # caminho relativo resolvido; absoluto fica
  expect_equal(p$begin_path[c(1, 3)],
               c("/Volumes/NAS/audio/ARA/ARA01_20211001_190000.wav",
                 "/abs/BAI01_20211001_190000.wav"))
})

test_that("every media file is a recording, with or without predictions", {
  dp <- pamdp_fixture()
  expect_message(pam <- read_pamdp(dp), "YYYYMMDD_HHMMSS")
  r <- pam$recordings
  expect_equal(nrow(r), 4)
  expect_setequal(r$site, c("ARA", "d2", "CAP"))
  expect_true("CAP/sem_data.wav" %in% r$source_audio)
  expect_equal(r$file_length[r$media_id == "m4"], 30)
  expect_true(all(pam$predictions$begin_path %in% r$source_audio))
})

test_that("site_column and datapackage.json are honoured", {
  dp <- pamdp_fixture()
  pam <- suppressMessages(read_pamdp(dp, site_column = "deploymentID"))
  expect_equal(unique(pam$predictions$site), c("d1", "d2"))
  expect_error(read_pamdp(dp, site_column = "habitat"), "no column")
  dir.create(file.path(dp, "tabelas"))
  file.rename(file.path(dp, "observations.csv"),
              file.path(dp, "tabelas", "obs.csv"))
  expect_error(suppressMessages(read_pamdp(dp)), "not found")
  jsonlite::write_json(list(resources = list(
    list(name = "observations", path = "tabelas/obs.csv"))),
    file.path(dp, "datapackage.json"), auto_unbox = TRUE)
  pam <- suppressMessages(read_pamdp(dp))
  expect_equal(nrow(pam$predictions), 4)
})

test_that("bad tables stop with a clear error", {
  dp <- pamdp_fixture()
  expect_error(read_pamdp(file.path(dp, "nada")), "folder")
  obs <- utils::read.csv(file.path(dp, "observations.csv"))
  obs$classificationProbability[1] <- 1.5
  utils::write.csv(obs, file.path(dp, "observations.csv"), row.names = FALSE)
  expect_error(suppressMessages(read_pamdp(dp)), "outside 0-1")
  obs$classificationMethod <- "human"
  utils::write.csv(obs, file.path(dp, "observations.csv"), row.names = FALSE)
  expect_error(suppressMessages(read_pamdp(dp)), "No machine prediction")
  med <- utils::read.csv(file.path(dp, "media.csv"))
  med$filePath <- NULL
  utils::write.csv(med, file.path(dp, "media.csv"), row.names = FALSE)
  expect_error(suppressMessages(read_pamdp(dp)), "filePath")
})
