# Resumo de run_simpsi_boot.R: por conjunto, junta os draws de psi medio das
# replicas do estagio 1 e compara com o psi medio verdadeiro (vies da
# mediana, cobertura de 90% e de 95%); por cenario, medias e erro-padrao de
# Monte Carlo da cobertura.
#   Rscript dev/fase2/summarise_simpsi_boot.R OUT_DIR
out <- commandArgs(TRUE)[1]
fs <- Sys.glob(file.path(out, "task_*.rds"))
x <- lapply(fs, readRDS)
tk <- do.call(rbind, lapply(x, \(r) data.frame(r$task[c("type", "r", "k", "id")], err = !is.na(r$error),
  div = if (is.null(r$div)) NA else r$div, rhat = if (is.null(r$rhat)) NA else r$rhat,
  ess = if (is.null(r$ess)) NA else r$ess, seconds = r$seconds)))
cat("tasks:", nrow(tk), " com erro:", sum(tk$err), " com divergencias:", sum(tk$div > 0, na.rm = TRUE),
    " R-hat > 1,01:", sum(tk$rhat > 1.01, na.rm = TRUE), " ESS min:", min(tk$ess, na.rm = TRUE),
    " minutos medios:", round(mean(tk$seconds) / 60, 1), "\n")
key <- paste(tk$type, tk$r)
sets <- lapply(split(seq_along(x), key), \(ii) {
  ok <- ii[!tk$err[ii]]
  dr <- unlist(lapply(x[ok], `[[`, "psi_bar"))
  tr <- x[[ii[1]]]$truth$psi_bar
  q <- quantile(dr, c(.025, .05, .5, .95, .975))
  data.frame(type = tk$type[ii[1]], r = tk$r[ii[1]], n_rep = length(ok), psi = tr, med = q[[3]],
             lo90 = q[[2]], hi90 = q[[4]], lo95 = q[[1]], hi95 = q[[5]],
             sd_entre = sd(vapply(x[ok], \(r) median(r$psi_bar), 0)),
             sd_dentro = mean(vapply(x[ok], \(r) sd(r$psi_bar), 0)))
})
s <- do.call(rbind, sets)
s$vies <- s$med - s$psi
s$cob90 <- s$lo90 <= s$psi & s$psi <= s$hi90
s$cob95 <- s$lo95 <= s$psi & s$psi <= s$hi95
s$largura90 <- s$hi90 - s$lo90
agg <- do.call(rbind, lapply(split(s, s$type), \(g) data.frame(
  cenario = g$type[1], conjuntos = nrow(g), psi = mean(g$psi), vies = mean(g$vies),
  vies_ep = sd(g$vies) / sqrt(nrow(g)), cob90 = mean(g$cob90),
  cob90_ep = sqrt(mean(g$cob90) * (1 - mean(g$cob90)) / nrow(g)), cob95 = mean(g$cob95),
  largura90 = mean(g$largura90), sd_entre = mean(g$sd_entre), sd_dentro = mean(g$sd_dentro))))
print(agg, digits = 3, row.names = FALSE)
saveRDS(list(tasks = tk, sets = s, agg = agg), file.path(out, "resumo_simpsi_boot.rds"))
