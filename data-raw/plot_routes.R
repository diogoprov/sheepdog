# =============================================================================
# plot_routes.R
#
# Graficos com dados simulados, baseados nos de Larissa S. M. Sugai:
#   vignettes/articles/figures/routes.png: as quatro rotas ate o historico
#   pkgdown/assets/figures/thresholds.png: os dois limiares e sua comparacao
# Uso: rode a partir da raiz do repositorio.
# Dependencias: install.packages(c("ggplot2", "patchwork", "MASS"))
# =============================================================================
library(ggplot2)
library(patchwork)

azul <- "#1f5c8b"; azul_claro <- "#d9e9f8"
ocre <- "#8a5a00"; ocre_claro <- "#fceecf"
cinza <- "#7f8c99"; escuro <- "#2c3e50"; vermelho <- "#a33a3a"

tema <- theme_minimal(base_size = 10, base_family = "Helvetica") +
  theme(panel.grid.minor = element_blank(),
        plot.title = element_text(size = 10.5, colour = escuro),
        axis.title = element_text(colour = "#5d6b78"))
eixos <- list(
  scale_x_continuous("Confidence score", breaks = seq(0.2, 1, 0.2)),
  scale_y_continuous(breaks = c(0, 0.5, 1)),
  coord_cartesian(xlim = c(0.1, 1), ylim = c(-0.05, 1.05)))

# Clipes revisados e curva ajustada ----------------------------------------
set.seed(11)
n <- 300
score <- sort(runif(n, 0.1, 0.999))
verdict <- rbinom(n, 1, plogis(-3.5 + 2 * qlogis(score) + 3.6 * score))
ajuste <- glm(verdict ~ qlogis(score), binomial)

grade <- seq(0.1, 0.999, 0.002)
x <- cbind(1, qlogis(grade))
media <- as.numeric(plogis(x %*% coef(ajuste)))
amostras <- plogis(x %*% t(MASS::mvrnorm(200, coef(ajuste), vcov(ajuste))))
faixa <- data.frame(
  grade, media,
  lo = apply(amostras, 1, quantile, 0.05),
  hi = apply(amostras, 1, quantile, 0.95))

p_min <- 0.95
primeiro <- function(ok) grade[which(ok)[1]]
corte_1 <- primeiro(media >= p_min)
corte_2 <- primeiro(rowMeans(amostras >= p_min) >= 0.9)
precisao <- rev(cumsum(rev(verdict)) / seq_along(verdict))
corte_a <- score[which(precisao >= 0.9 & rev(seq_along(score)) >= 15)[1]]

# Rotas ---------------------------------------------------------------------
rota_a <- ggplot(data.frame(score, verdict), aes(score, verdict)) +
  annotate("rect", xmin = corte_a, xmax = Inf, ymin = -Inf, ymax = Inf,
           fill = azul_claro, alpha = 0.6) +
  geom_jitter(height = 0.02, width = 0, size = 0.8, colour = cinza,
              alpha = 0.7) +
  geom_vline(xintercept = corte_a, colour = azul) + eixos +
  labs(title = "A. Empirical threshold", y = "Verdict") + tema

curva <- function(titulo, corte, faixa_on = FALSE) {
  g <- ggplot(faixa, aes(grade, media))
  if (faixa_on) {
    g <- g + geom_ribbon(aes(ymin = lo, ymax = hi), fill = ocre_claro)
  }
  g + geom_line(colour = ocre) +
    geom_hline(yintercept = p_min, linetype = 2, colour = cinza) +
    geom_vline(xintercept = corte, colour = ocre) + eixos +
    labs(title = titulo, y = "P(tp)") + tema
}

ids <- sample(200, 25)
linhas <- data.frame(grade = rep(grade, 25), p = as.numeric(amostras[, ids]),
                     k = rep(ids, each = length(grade)))
cortes <- data.frame(x = apply(amostras[, ids], 2,
                               \(p) grade[which(p >= p_min)[1]]))
rota_3 <- ggplot(linhas, aes(grade, p, group = k)) +
  geom_line(colour = ocre, alpha = 0.25, linewidth = 0.3) +
  geom_hline(yintercept = p_min, linetype = 2, colour = cinza) +
  geom_rug(data = cortes, aes(x = x), inherit.aes = FALSE, colour = ocre,
           sides = "b") + eixos +
  labs(title = "B, way 3. history_draws()", y = "P(tp)") + tema

dir.create("vignettes/articles/figures", showWarnings = FALSE)
ggsave("vignettes/articles/figures/routes.png",
       (rota_a | curva("B, way 1. rule = \"mean\"", corte_1)) /
         (curva("B, way 2. rule = \"probability\"", corte_2, TRUE) | rota_3),
       width = 7.2, height = 5, dpi = 200, bg = "white")

# Limiares ------------------------------------------------------------------
# A: precisao dos clipes acima de cada corte, com apoio de ao menos min_n
cortes_a <- data.frame(score, precisao, apoio = rev(seq_along(score)))
limiar_a <- ggplot(subset(cortes_a, apoio >= 15), aes(score, precisao)) +
  geom_line(colour = azul) +
  geom_hline(yintercept = 0.9, linetype = 2, colour = cinza) +
  geom_vline(xintercept = corte_a, colour = azul) + eixos +
  labs(title = "A. Precision of the clips above each cut", y = "Precision") +
  tema

# B: a curva de duas especies e onde cruzam p_min
duas <- rbind(data.frame(grade, p = plogis(1 + 2.2 * qlogis(grade)),
                         species = "boa_ran"),
              data.frame(grade, p = plogis(-0.4 + 2 * qlogis(grade)),
                         species = "den_nan"))
cruza <- do.call(rbind, lapply(split(duas, duas$species), \(d) {
  data.frame(x = d$grade[which(d$p >= p_min)[1]], species = d$species[1])
}))
limiar_b <- ggplot(duas, aes(grade, p, linetype = species)) +
  geom_line(colour = ocre) +
  geom_hline(yintercept = p_min, linetype = 2, colour = cinza) +
  geom_vline(data = cruza, aes(xintercept = x, linetype = species),
             colour = ocre, linewidth = 0.3) + eixos +
  scale_linetype_manual(NULL, values = c(boa_ran = 1, den_nan = 4)) +
  labs(title = "B. Where each curve reaches p_min", y = "P(tp)") + tema +
  theme(legend.position = "inside", legend.position.inside = c(0.2, 0.55))

# Escolha do modelo: o mais simples a um erro padrao do melhor
cv <- data.frame(model = factor(paste0("m", 0:4)),
                 log_loss = c(0.52, 0.44, 0.41, 0.405, 0.40),
                 se = c(0.02, 0.02, 0.02, 0.02, 0.025))
modelos <- ggplot(cv, aes(model, log_loss)) +
  geom_hline(yintercept = 0.425, linetype = 2, colour = cinza) +
  geom_pointrange(aes(ymin = log_loss - se, ymax = log_loss + se,
                      colour = model == "m2"), size = 0.3) +
  scale_colour_manual(values = c(`TRUE` = ocre, `FALSE` = cinza),
                      guide = "none") +
  labs(title = "Model choice: within one SE of the best", x = NULL,
       y = "Held-out log-loss") + tema

# Comparacao, como em compare_thresholds()
pontos <- data.frame(a = c(0.45, 0.52, 0.6, 0.68, 0.74, 0.5, 0.82),
                     b = c(0.47, 0.5, 0.63, 0.66, 0.77, 0.74, 0.58))
pontos$flag <- ifelse(abs(pontos$a - pontos$b) <= 0.05, "agree", "disagree")
compara <- ggplot(pontos, aes(a, b, colour = flag)) +
  annotate("polygon", x = c(0.3, 1, 1, 0.3), y = c(0.25, 0.95, 1.05, 0.35),
           fill = azul_claro, alpha = 0.6) +
  geom_abline(linetype = 2, colour = cinza) + geom_point(size = 1.8) +
  scale_colour_manual(NULL, values = c(agree = azul, disagree = vermelho)) +
  coord_equal(xlim = c(0.3, 1), ylim = c(0.3, 1)) +
  labs(title = "compare_thresholds()", x = "Empirical threshold",
       y = "Model threshold") + tema +
  theme(legend.position = "inside", legend.position.inside = c(0.8, 0.2))

dir.create("pkgdown/assets/figures", recursive = TRUE, showWarnings = FALSE)
ggsave("pkgdown/assets/figures/thresholds.png",
       (limiar_a | limiar_b) / (modelos | compara),
       width = 7.2, height = 5.4, dpi = 200, bg = "white")
