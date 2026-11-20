# Conjuntos de teste do Curiango (Cjto-Teste_01 a _03), reconstruidos das
# saidas do BirdNET e do custom que a Liliana guardou no NAS (19/11/2026).
# Cruza a lista de arquivos de cada conjunto com crywolf::curiango$verified e
# $minutes: composicao, selecao de ct01+ct02 dado ano-mes x hora x sitio,
# pesos de Hajek e BirdNET dos outputs dela contra o do deposito.
#
# Uso: Rscript dev/fase2/curiango_conjuntos_teste.R <pasta>
# <pasta> contem liliana_zip/, o Evaluation.zip extraido (pastas
# 03_output_*_ct0*, 03.01_output_*_ct01-02 e Evaluation). Os arquivos nao
# estao no repositorio; o zip fica na pasta do Box do codigo FrogNet.
suppressMessages(library(dplyr))
base <- file.path(commandArgs(TRUE)[1], "liliana_zip")
lst <- function(d) {
  f <- readLines(file.path(base, d, "BirdNET_SelectionTable.list.txt"))
  tibble(file = sub("\\.flac$", "", sub(".*\\\\", "", f)))
}
sets <- bind_rows(ct01 = lst("03_output_Birdnet_ct01"), ct02 = lst("03_output_Birdnet-ct02"),
                  ct03 = lst("03_output_Birdnet-ct03"), .id = "ct")
sets <- sets |> mutate(site = sub("^DIVSPTS01_44p1K_([A-Z]+)_.*", "\\1", file),
                       time = as.POSIXct(sub(".*_(\\d{8}_\\d{6})$", "\\1", file), format = "%Y%m%d_%H%M%S", tz = "UTC"))
cat("arquivos por ct:\n"); print(table(sets$ct)); cat("duplicados entre ct:", sum(duplicated(sets$file)), "\n")
v <- crywolf::curiango$verified |> mutate(time = as.POSIXct(format(time, "%Y-%m-%d %H:%M:%S"), tz = "UTC"))
m <- crywolf::curiango$minutes |> mutate(time = as.POSIXct(format(time, "%Y-%m-%d %H:%M:%S"), tz = "UTC"))
j <- full_join(sets, v |> mutate(ver = TRUE), by = c("site", "time"))
cat("verificados sem ct:", sum(is.na(j$ct)), " ct sem verificado:", sum(is.na(j$ver)), "\n")
jj <- inner_join(sets, v, by = c("site", "time")) |> left_join(m |> select(site, time, conf_custom, conf_birdnet), by = c("site", "time"))
pop <- m |> summarise(ct = "populacao", n = n(), y = NA, bn_pos = mean(conf_birdnet > 0), cu04 = mean(conf_custom >= 0.4),
                      mes7_11_h18_3 = mean(as.integer(format(time, "%m")) %in% 7:11 & as.integer(format(time, "%H")) %in% c(18:23, 0:3)))
res <- jj |> group_by(ct) |> summarise(n = n(), y = mean(y), bn_pos = mean(conf_birdnet > 0, na.rm = TRUE), cu04 = mean(conf_custom >= 0.4, na.rm = TRUE),
            mes7_11_h18_3 = mean(as.integer(format(time, "%m")) %in% 7:11 & as.integer(format(time, "%H")) %in% c(18:23, 0:3)))
print(bind_rows(res, pop), width = 200)
cat("\nmeses por ct:\n"); print(table(jj$ct, format(jj$time, "%m")))
cat("\nhoras por ct:\n"); print(table(jj$ct, format(jj$time, "%H")))
cat("\nsitios por ct:\n"); print(table(jj$ct, jj$site)); print(round(prop.table(table(m$site)), 3))
# BirdNET dos outputs da Liliana vs deposito
rd <- function(d) {
  fs <- list.files(file.path(base, d), pattern = "selection.table.txt$", full.names = TRUE)
  bind_rows(lapply(fs, \(f) { x <- read.delim(f, check.names = FALSE); x$file <- sub("\\.BirdNET.*", "", basename(f)); x }))
}
b <- bind_rows(rd("03_output_Birdnet_ct01"), rd("03_output_Birdnet-ct02"), rd("03_output_Birdnet-ct03"))
bm <- b |> group_by(file) |> summarise(bn_lil = max(ifelse(`Common Name` == "Common Pauraque", Confidence, 0)))
cmp <- inner_join(bm, sets, by = "file") |> inner_join(m, by = c("site", "time"))
cat("\nBirdNET max por minuto, Liliana vs deposito: n =", nrow(cmp), " iguais (1e-3):", mean(abs(cmp$bn_lil - cmp$conf_birdnet) < 1e-3),
    " cor:", round(cor(cmp$bn_lil, cmp$conf_birdnet), 3), "\n")
print(head(cmp[abs(cmp$bn_lil - cmp$conf_birdnet) >= 1e-3, c("file", "bn_lil", "conf_birdnet")]))
cat("\n--- ct01+ct02 vs populacao ---\n")
r <- filter(jj, ct != "ct03")
pm <- table(factor(format(m$time, "%m"), levels = sprintf("%02d", 1:12)))
rm_ <- table(factor(format(r$time, "%m"), levels = sprintf("%02d", 1:12)))
print(rbind(pop = round(100 * prop.table(pm), 1), ct12 = round(100 * prop.table(rm_), 1)))
print(chisq.test(rm_, p = prop.table(pm)))
ph <- table(format(m$time, "%H")); rh <- table(factor(format(r$time, "%H"), levels = names(ph)))
print(rbind(pop = round(100 * prop.table(ph), 1), ct12 = round(100 * prop.table(rh), 1)))
print(chisq.test(rh, p = prop.table(ph)))
ps <- table(m$site); rs <- table(factor(r$site, levels = names(ps)))
print(rbind(N = ps, n = rs, pct = round(100 * rs / ps, 2)))
cat("positivos: "); print(table(jj$ct, jj$y))
cat("\n--- ano-mes ---\n")
ym <- function(t) format(t, "%Y-%m")
tp <- table(ym(m$time)); tr <- table(factor(ym(r$time), levels = names(tp)))
print(data.frame(pop = as.integer(tp), ct12 = as.integer(tr), pct = round(100 * as.integer(tr) / as.integer(tp), 2), row.names = names(tp)))
cat("\n--- selecao de ct01+ct02: os scores importam depois de ano-mes, hora e sitio? ---\n")
pp <- m |> left_join(distinct(r, site, time) |> mutate(inc = 1L), by = c("site", "time")) |>
  mutate(inc = coalesce(inc, 0L), ym = ym(time), h = format(time, "%H"),
         lbn = qlogis(pmin(pmax(conf_birdnet, 1e-3), 1 - 1e-3)), lcu = qlogis(pmin(pmax(conf_custom, 1e-3), 1 - 1e-3)))
f0 <- glm(inc ~ ym + h + site, binomial, pp); f1 <- update(f0, . ~ . + lbn + lcu)
print(anova(f0, f1, test = "LRT")); print(summary(f1)$coefficients[c("lbn", "lcu"), ])
fbase <- glm(inc ~ site, binomial, pp); cat("LRT ano-mes + hora:\n"); print(anova(fbase, f0, test = "LRT"))
pi <- fitted(f0)[pp$inc == 1]; w <- 1 / pi; cat("Kish n_eff ct01+02 com pesos de ano-mes x hora x sitio:", round(sum(w)^2 / sum(w^2)), "de", length(w), "\n")
yy <- r$y[match(paste(pp$site, pp$time)[pp$inc == 1], paste(r$site, r$time))]
cat("prevalencia ct01+02: crua", round(mean(yy), 3), " Hajek", round(sum(w * yy) / sum(w), 3), "\n")
