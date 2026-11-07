# =============================================================================
# plot_scores.R
#
# De onde vem o falso positivo: as distribuicoes dos scores de deteccoes
# verdadeiras e falsas se sobrepoem. Curvas ilustrativas, nao sao dados.
# Saida: pkgdown/assets/figures/score_overlap.png
# Uso: rode a partir da raiz do repositorio.
# Dependencias: install.packages("ggplot2")
# =============================================================================
library(ggplot2)

azul <- "#1f5c8b"; ocre <- "#8a5a00"; ocre_claro <- "#fceecf"
escuro <- "#2c3e50"; vermelho <- "#a33a3a"

grade <- seq(0.001, 0.999, 0.001)
falsas <- dbeta(grade, 2.2, 6)
verdadeiras <- dbeta(grade, 6, 2.2)
curvas <- data.frame(
  score = rep(grade, 2), densidade = c(falsas, verdadeiras),
  tipo = rep(c("false", "true"), each = length(grade)))

# a faixa em que as duas curvas tem ao menos 10% do proprio pico
faixa <- range(grade[falsas >= 0.1 * max(falsas) &
                       verdadeiras >= 0.1 * max(verdadeiras)])
topo <- max(curvas$densidade)

p <- ggplot(curvas, aes(score, densidade, colour = tipo, fill = tipo)) +
  annotate("rect", xmin = faixa[1], xmax = faixa[2], ymin = -Inf, ymax = Inf,
           fill = ocre_claro) +
  geom_area(position = "identity", alpha = 0.25, linewidth = 0.8) +
  annotate("text", x = mean(faixa), y = topo * 1.08, label = "can be both",
           colour = ocre, size = 4.2, fontface = "bold") +
  annotate("text", x = 0.2, y = topo * 1.08, label = "false detections",
           colour = vermelho, size = 3.6) +
  annotate("text", x = 0.8, y = topo * 1.08, label = "true detections",
           colour = azul, size = 3.6) +
  scale_colour_manual(values = c(false = vermelho, true = azul),
                      guide = "none") +
  scale_fill_manual(values = c(false = vermelho, true = azul), guide = "none") +
  scale_x_continuous("Confidence score", breaks = seq(0, 1, 0.2),
                     expand = c(0, 0)) +
  scale_y_continuous("Detections", breaks = NULL,
                     expand = expansion(c(0, 0.05))) +
  coord_cartesian(ylim = c(0, topo * 1.15)) +
  theme_minimal(base_size = 10, base_family = "Helvetica") +
  theme(panel.grid = element_blank(),
        axis.title = element_text(colour = "#5d6b78"),
        axis.line.x = element_line(colour = "#7f8c99"))

dir.create("pkgdown/assets/figures", recursive = TRUE, showWarnings = FALSE)
ggsave("pkgdown/assets/figures/score_overlap.png", p,
       width = 6, height = 2.8, dpi = 200, bg = "white")
