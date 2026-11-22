# Validacao por noite do v1 no Curiango (passo 1 do plano de 21/11/2026, com
# o alvo do v1 redefinido como ocupacao por sitio-noite).
# Noites G+: sitio-noites sem nenhum minuto com score >= 0,4 e com pelo menos
# um minuto verificado positivo (ct12 ou ct03). Os dois modelos sao
# reajustados sem os rotulos dessas noites e comparados pela probabilidade de
# ocupacao que dao a elas, contra as outras noites sem score alto:
#   * v1 de dois estagios, emissoes por faixa (emissions_bins.rds), Markov;
#   * fp_occu() do crywolf com limiar 0,40 e markov = "time" (o ind_mk da
#     vinheta dynamic: occ ~ temp_d + rh_d, det ~ bio + aci, fp ~ temp + rh,
#     recorder aleatorio, sitio = sitio-noite).
# As emissoes por faixa foram estimadas com o ct12 inteiro, que inclui 3
# positivos de noites G+ (vazamento pequeno, registrado).
#   Rscript dev/fase2/curiango_validacao_noite.R prep OUT_DIR PI_CSV EMIS_RDS
#   Rscript dev/fase2/curiango_validacao_noite.R fp OUT_DIR
#   (v1: run_curiango_2stage.R OUT_DIR/v1 OUT_DIR/emissions_semGplus.rds 1 4 1000 1000 0)
#   Rscript dev/fase2/curiango_validacao_noite.R resumo OUT_DIR [n_draws]
source("dev/fase2/curiango_v1.R")
a <- commandArgs(TRUE); modo <- a[1]; out <- a[2]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
d <- curiango_v1("custom", c_lo = qlogis(0.1)); st <- d$stan; m <- d$minutes
prob <- ifelse(st$cens == 1L, 0, plogis(st$s))
sn_min <- paste(m$site, d$night)
sn_site <- sn_min[st$first]                       # um por sitio-noite (ordem do Stan)
hi_site <- tapply(prob >= 0.4, factor(sn_min, unique(sn_min)), any)[sn_site]
max_site <- tapply(prob, factor(sn_min, unique(sn_min)), max)[sn_site]

if (modo == "prep") {
  p <- read.csv(a[3])
  j <- match(paste(p$site, p$time), paste(m$site, format(m$time, "%Y-%m-%d %H:%M:%S"))); stopifnot(!anyNA(j))
  p$sn <- sn_min[j]
  gplus <- unique(p$sn[p$y == 1 & !hi_site[match(p$sn, sn_site)]])
  em <- readRDS(a[4])
  v <- st$v; v[sn_min %in% gplus] <- -1L
  em$v <- v
  saveRDS(em, file.path(out, "emissions_semGplus.rds"))
  saveRDS(list(gplus = gplus, removidos = sum(st$v >= 0L & sn_min %in% gplus)), file.path(out, "gplus.rds"))
  cat("noites G+:", length(gplus), " rotulos removidos:", sum(st$v >= 0L & sn_min %in% gplus), "\n")
}

if (modo == "fp") {
  library(crywolf)
  g <- readRDS(file.path(out, "gplus.rds"))$gplus
  zs <- function(x) as.numeric(scale(x))
  cm <- curiango$minutes; nt <- curiango$nights
  daily <- aggregate(cbind(temp, rh) ~ night, nt, mean)
  daily <- data.frame(night = daily$night, temp_d = zs(daily$temp), rh_d = zs(daily$rh))
  i <- match(cm$site_night, nt$site_night)
  auto <- data.frame(site = cm$site_night, time = cm$time, y = as.integer(cm$conf_custom >= 0.40),
                     bio = zs(cm$bio), aci = zs(cm$aci), temp = zs(nt$temp[i]), rh = zs(nt$rh[i]),
                     recorder = cm$site)
  sites <- data.frame(site = nt$site_night, night = nt$night)
  sites <- merge(sites, daily, by = "night", sort = FALSE)[, c("site", "temp_d", "rh_d")]
  vr <- curiango$verified
  # mesmo identificador de sitio-noite que o v1 (sitio + data da noite)
  vr$sn <- paste(vr$site, nt$night[match(vr$site_night, nt$site_night)])
  ver <- data.frame(site = vr$site_night, y = vr$y)[!vr$sn %in% g, ]
  dd <- fp_data(auto, sites, ver, site = "site", recorder = "recorder")
  t0 <- Sys.time()
  fit <- fp_occu(dd, occ = ~ temp_d + rh_d, det = ~ bio + aci, fp = ~ temp + rh, markov = "time",
                 chains = 4, threads_per_chain = 1, seed = 2026, refresh = 100)
  cat("segundos:", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "\n")
  fs <- fp_sites(fit)
  print(summary(fit))
  saveRDS(list(sites = fs, summary = summary(fit)), file.path(out, "fp_sites_semGplus.rds"))
}

if (modo == "resumo") {
  nd <- if (length(a) > 2) as.integer(a[3]) else 400L
  g <- readRDS(file.path(out, "gplus.rds"))$gplus
  em <- readRDS(file.path(out, "emissions_semGplus.rds"))
  fit <- readRDS(Sys.glob(file.path(out, "v1", "fit_*.rds"))[1])
  dr <- fit$draws; dr <- dr[round(seq(1, nrow(dr), length.out = nd)), , drop = FALSE]
  B <- dr[, grep("^beta\\[", colnames(dr)), drop = FALSE]
  A <- t(dr[, grep("^alpha\\[", colnames(dr)), drop = FALSE]); rho <- dr[, "rho[1]"]
  lpsi <- st$X %*% t(B)
  lse <- \(x, y) { mx <- pmax(x, y); mx + log(exp(x - mx) + exp(y - mx)) }
  lil <- \(x) plogis(x, log.p = TRUE); l1m <- \(x) plogis(x, lower.tail = FALSE, log.p = TRUE)
  v <- em$v
  pz <- vapply(seq_len(st$N_site), \(i) {
    ks <- st$first[i]:st$last[i]
    eta <- st$D[ks, , drop = FALSE] %*% A
    e1 <- ifelse(v[ks] == 0L, -Inf, em$e1[ks]); e0 <- ifelse(v[ks] == 1L, -Inf, em$e0[ks])
    a1 <- lil(eta[1, ]) + e1[1]; a0 <- l1m(eta[1, ]) + e0[1]
    for (k in seq_along(ks)[-1]) {
      if (st$adj[ks[k]] == 0L) {
        pr <- lse(a1, a0); n1 <- pr + lil(eta[k, ]); n0 <- pr + l1m(eta[k, ])
      } else {
        n1 <- lse(a1 + lil(eta[k, ] + rho), a0 + lil(eta[k, ]))
        n0 <- lse(a1 + l1m(eta[k, ] + rho), a0 + l1m(eta[k, ]))
      }
      a1 <- n1 + e1[k]; a0 <- n0 + e0[k]
    }
    L1 <- lse(a1, a0); lp0 <- sum(e0)
    mean(exp(lil(lpsi[i, ]) + L1 - lse(lil(lpsi[i, ]) + L1, l1m(lpsi[i, ]) + lp0)))
  }, 0)
  fs <- readRDS(file.path(out, "fp_sites_semGplus.rds"))$sites
  nt <- crywolf::curiango$nights
  key_fp <- paste(nt$site, nt$night)[match(fs$site, nt$site_night)]
  r <- data.frame(sn = sn_site, hi = hi_site, max = max_site, gplus = sn_site %in% g,
                  v1 = pz, fp = fs$occupied[match(sn_site, key_fp)])
  stopifnot(!anyNA(r$fp))
  auc <- \(x, grp) { rk <- rank(x); n1 <- sum(grp); n0 <- sum(!grp); (sum(rk[grp]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
  sem <- r[!r$hi, ]
  cat("sitio-noites:", nrow(r), " com score alto:", sum(r$hi), " sem:", nrow(sem), " G+:", sum(r$gplus), "\n")
  cat("\nP(ocupada) media por grupo\n")
  grp <- ifelse(r$hi, "com score alto", ifelse(r$gplus, "sem alto, G+", "sem alto, outras"))
  print(aggregate(cbind(v1, fp) ~ grp, r, \(x) round(mean(x), 3)))
  cat("\nnas noites sem score alto, por faixa do score maximo\n")
  sem$fx <- cut(sem$max, c(-1, 0.1, 0.2, 0.3, 0.4), right = FALSE)
  print(data.frame(fx = levels(sem$fx), n = as.vector(table(sem$fx)),
                   gplus = as.vector(tapply(sem$gplus, sem$fx, sum)),
                   v1 = round(as.vector(tapply(sem$v1, sem$fx, mean)), 3),
                   fp = round(as.vector(tapply(sem$fp, sem$fx, mean)), 3)))
  cat("\nAUC (G+ contra as outras noites sem score alto): v1", round(auc(sem$v1, sem$gplus), 3),
      " fp_occu", round(auc(sem$fp, sem$gplus), 3), "\n")
  cat("AUC dentro do score maximo 0,2 a 0,4: v1",
      round(with(sem[sem$max >= 0.2, ], auc(v1, gplus)), 3), " fp_occu",
      round(with(sem[sem$max >= 0.2, ], auc(fp, gplus)), 3), "\n")
  cat("\nG+ uma a uma\n"); print(r[r$gplus, c("sn", "max", "v1", "fp")], digits = 3, row.names = FALSE)
  cat("\nocupacao media (soma de P(ocupada) / sitio-noites): v1", round(mean(r$v1), 3),
      " fp_occu", round(mean(r$fp), 3), " piso (score alto)", round(mean(r$hi), 3), "\n")
  saveRDS(r, file.path(out, "validacao_noite.rds"))
}
