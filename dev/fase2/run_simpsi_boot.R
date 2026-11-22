# Cobertura de psi com o bootstrap do estagio 1 (criterio 2 reescrito; desenho
# no PLANO, "Cobertura de psi: desenho"). Um task por (cenario, conjunto,
# replica): regera o conjunto com o gerador de sim_psi_curiango.R
# (sim_psi_core.R, mesmas sementes), sorteia sitio-noites do deposito com
# reposicao para o estagio 1 por faixas, aplica as emissoes da replica a todos
# os minutos e ajusta o estagio 2 (Markov, 2 cadeias de 500 + 500). Cada task
# grava OUT_DIR/task_<id>.rds, entao uma rodada parada retoma.
#   Rscript dev/fase2/run_simpsi_boot.R prep INPUTS_RDS FIT_BINS EMIS_BINS CALIB_RDS   (no Mac)
#   Rscript dev/fase2/run_simpsi_boot.R OUT_DIR [N_WORKERS] [N_SETS] [N_BOOT] [INPUTS_RDS] [IDS]
suppressPackageStartupMessages(library(parallel))
source("dev/fase2/emissions_bins_curiango.R")   # emis_bins, breaks (curiango_v1 so no prep)
source("dev/fase2/sim_psi_core.R")
a <- commandArgs(TRUE)

if (a[1] == "prep") {
  d <- curiango_v1("custom", c_lo = qlogis(0.1)); st <- d$stan; m <- d$minutes
  fit0 <- readRDS(a[3]); med <- setNames(fit0$summary$median, fit0$summary$variable)
  em <- readRDS(a[4]); cal <- readRDS(a[5])$cal
  S <- simpsi_setup(st, paste(m$site, d$night),
                    drop(st$X %*% med[grep("^beta\\[", names(med))]),
                    drop(st$D %*% med[grep("^alpha\\[", names(med))]), em$f0, em$f1, breaks)
  nights <- d$night[st$first]
  S$night <- match(nights, sort(unique(nights))); S$N_night <- length(unique(nights))
  S$par <- lapply(cal, \(x) x$par)
  saveRDS(S, a[2])
  cat("inputs:", a[2], round(file.size(a[2]) / 1e6, 1), "MB\n")
  quit(save = "no")
}

suppressPackageStartupMessages(library(cmdstanr))
out <- a[1]
workers <- if (length(a) > 1) as.integer(a[2]) else 4L
n_sets <- if (length(a) > 2) as.integer(a[3]) else 50L
n_boot <- if (length(a) > 3) as.integer(a[4]) else 10L
S <- readRDS(if (length(a) > 4) a[5] else "dev/fase2/inputs/simpsi_inputs.rds")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
mod <- cmdstan_model("dev/fase2/model_v1_2stage.stan", dir = out, quiet = TRUE)
grid <- expand.grid(k = seq_len(n_boot), r = seq_len(n_sets), type = c("ind", "pers", "pers0"),
                    stringsAsFactors = FALSE)
grid$id <- seq_len(nrow(grid))
if (length(a) > 5) grid <- grid[grid$id %in% eval(parse(text = a[6])), ]
st <- S$st

run_task <- function(g) {
  file <- file.path(out, sprintf("task_%05d.rds", g$id))
  if (file.exists(file)) return(invisible(NULL))
  t0 <- Sys.time()
  par <- S$par[[g$type]]
  x <- simpsi_set(S, g$type, par, g$r)
  # replica k do bootstrap por sitio-noite do estagio 1 (sementes por conjunto)
  gr <- split(seq_len(S$N), S$noite)
  idx <- withr::with_seed(9026 + 1000 * S$ids[[g$type]] + g$r, {
    for (kk in seq_len(g$k)) ii <- unlist(gr[sample.int(length(gr), replace = TRUE)], use.names = FALSE)
    ii
  })
  y <- rep(NA_integer_, S$N); y[x$lab12] <- x$w[x$lab12]
  rb <- emis_bins(x$b[idx], x$lab12[idx], y[idx], x$wt[idx])
  dat <- st[c("N_site", "N_occ", "first", "last", "P_psi", "X", "P_theta", "D", "adj")]
  dat$v <- ifelse(x$lab12 | x$lab03, x$w, -1L)
  dat$e0 <- log(rb$f0[x$b]); dat$e1 <- log(rb$f1[x$b])
  dat$markov <- 1L; dat$night_re <- 0L; dat$N_night <- S$N_night; dat$night <- S$night
  wd <- tempfile("fit"); dir.create(wd); on.exit(unlink(wd, recursive = TRUE))
  r <- tryCatch({
    fit <- suppressWarnings(mod$sample(
      data = dat, chains = 2, parallel_chains = 1, iter_warmup = 500, iter_sampling = 500,
      adapt_delta = 0.95, seed = g$id, refresh = 0, output_dir = wd,
      show_messages = FALSE, show_exceptions = FALSE,
      init = \(chain_id) list(beta = rep(0, dat$P_psi), alpha = rep(0, dat$P_theta), rho = rep(0, 1),
                              sigma_night = numeric(0), u_night = numeric(0))))
    dr <- posterior::as_draws_matrix(fit$draws(c("beta", "rho")))
    B <- dr[, grep("^beta\\[", colnames(dr)), drop = FALSE]
    sm <- as.data.frame(fit$summary(c("beta", "alpha", "rho", "psi_c", "theta_bar")))
    list(psi_bar = colMeans(plogis(st$X %*% t(B))), rho = as.numeric(dr[, "rho[1]"]),
         rhat = max(sm$rhat, na.rm = TRUE), ess = min(sm$ess_bulk, na.rm = TRUE),
         div = sum(fit$diagnostic_summary(quiet = TRUE)$num_divergent), error = NA_character_)
  }, error = \(e) list(error = conditionMessage(e)))
  r$task <- g
  r$truth <- list(psi_bar = mean(plogis(S$lpsi0 + par[["dpsi"]])), z_bar = mean(x$z),
                  prev = mean(x$w), f1_hi = rb$f1[S$nb])
  r$seconds <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  saveRDS(r, file)
}

tasks <- split(grid, grid$id)
cat("tasks:", length(tasks), " workers:", workers, "\n")
done <- mclapply(tasks, run_task, mc.cores = workers, mc.preschedule = FALSE)
bad <- vapply(done, inherits, logical(1), "try-error")
cat("tasks:", length(tasks), " failed:", sum(bad), "\n")
if (any(bad)) print(unique(unlist(lapply(done[bad], as.character))))
