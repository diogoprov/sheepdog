# =============================================================================
# plot_occupancy.R
#
# Figuras da ocupacao com falsos positivos, adaptadas do artigo "How crywolf
# works" (data-raw/explainer do crywolf) para a paleta do sheepdog:
#   occupancy_model.png:     as duas historias de cada sitio
#   occupancy_mixture.png:   sitios vazios e ocupados se sobrepoem
#   occupancy_threshold.png: o limiar transforma scores em deteccoes
#   occupancy_routes.png:    do export aos resultados
# Saida: pkgdown/assets/figures/. Exemplos ilustrativos, nao sao dados.
# Uso: rode a partir da raiz do repositorio.
# Dependencias: ggplot2 e Graphviz (dot).
# =============================================================================
library(ggplot2)

azul <- "#1f5c8b"; vermelho <- "#a33a3a"; roxo <- "#5e3a7a"
roxo_claro <- "#efe2f8"; cinza <- "#7f8c99"; escuro <- "#2c3e50"
saida <- "pkgdown/assets/figures"
dir.create(saida, recursive = TRUE, showWarnings = FALSE)

tema <- theme_minimal(base_size = 10, base_family = "Helvetica") +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major.x = element_blank(),
        axis.title = element_text(colour = "#5d6b78"))

# Mistura: sitios esperados em 200, com p11 = 0,25 e p10 = 0,05 ---------------
k <- 0:15
grupos <- rbind(
  data.frame(k, n = 100 * dbinom(k, 20, 0.05), grupo = "empty sites"),
  data.frame(k, n = 100 * dbinom(k, 20, 0.25), grupo = "occupied sites"))
mistura <- ggplot(grupos, aes(k, n, fill = grupo)) +
  annotate("rect", xmin = 0.5, xmax = 4.5, ymin = -Inf, ymax = Inf,
           fill = roxo_claro) +
  geom_col(position = position_dodge(width = 0.86), width = 0.8) +
  annotate("text", x = 2.5, y = 42, label = "could be either", size = 3.6,
           colour = roxo, fontface = "bold") +
  scale_fill_manual(NULL, values = c("empty sites" = vermelho,
                                     "occupied sites" = azul)) +
  scale_x_continuous(breaks = seq(0, 15, 5)) +
  labs(x = "Nights with a detection, out of 20",
       y = "Expected sites, of 200") +
  tema + theme(legend.position = "top", legend.justification = "left")
ggsave(file.path(saida, "occupancy_mixture.png"), mistura, width = 5,
       height = 3.2, dpi = 200, bg = "white")

# Limiar: uma ocasiao e deteccao quando alguma predicao o alcanca -------------
scores <- data.frame(
  occasion = rep(1:5, c(3, 2, 1, 4, 0)),
  score = c(0.82, 0.52, 0.36, 0.40, 0.22, 0.68, 0.58, 0.45, 0.30, 0.12))
scores$above <- scores$score >= 0.5
y <- data.frame(occasion = 1:5, label = paste("y =", c(1, 0, 1, 1, 0)))
limiar <- ggplot(scores, aes(occasion, score)) +
  geom_hline(yintercept = 0.5, colour = vermelho, linewidth = 0.7,
             linetype = "dashed") +
  geom_point(aes(colour = above), size = 2.6) +
  geom_text(data = y, aes(occasion, -0.1, label = label), size = 3.4,
            colour = escuro) +
  annotate("text", x = 5.45, y = 0.55, label = "threshold", hjust = 1,
           size = 3.3, colour = vermelho) +
  scale_colour_manual(values = c("TRUE" = azul, "FALSE" = "#b6bfc7"),
                      guide = "none") +
  scale_x_continuous("Occasion", breaks = 1:5, limits = c(0.5, 5.5)) +
  scale_y_continuous("Score", breaks = c(0, 0.5, 1)) +
  coord_cartesian(ylim = c(-0.15, 1)) + tema
ggsave(file.path(saida, "occupancy_threshold.png"), limiar, width = 5,
       height = 3, dpi = 200, bg = "white")

# Fluxogramas -----------------------------------------------------------------
for (nome in c("model", "routes")) {
  status <- system2("dot", c(
    "-Tpng", "-Gdpi=200", file.path("data-raw", paste0("occupancy_", nome, ".dot")),
    "-o", file.path(saida, paste0("occupancy_", nome, ".png"))))
  stopifnot(status == 0)
}
