# Fig. 2 do artigo: (a) checagem preditiva da calibracao por mes; (b) parte
# da variancia posterior dos coeficientes devida a calibracao. Le as tabelas
# de inst/benchmarks/ do repositorio. Rode a partir de manuscript/:
#   Rscript dev/manuscript-mee/fig2-curiango.R
suppressPackageStartupMessages({library(ggplot2); library(dplyr); library(patchwork)})
invisible(Sys.setlocale("LC_TIME", "C"))   # meses em ingles
bench <- "dev/benchmarks/results/ct12/original"
rotulo <- c(custom = "Custom", birdnet = "BirdNET")

ppc <- read.csv(file.path(bench, "curiango-flow-ppc.csv")) |>
  filter(check == "month") |>
  mutate(classifier = factor(rotulo[classifier], levels = rotulo),
         month = as.Date(paste0(group, "01"), "%Y%m%d"))
a <- ggplot(ppc, aes(month)) +
  geom_linerange(aes(ymin = pred_lower, ymax = pred_upper), colour = "grey55",
                 linewidth = 1.6) +
  geom_point(aes(y = observed, fill = flagged, size = n), shape = 21) +
  scale_fill_manual(values = c(`FALSE` = "white", `TRUE` = "#b2182b"),
                    labels = c("no", "yes"), name = "Flagged") +
  scale_size_area(max_size = 3.5, name = "Reviewed minutes", breaks = c(10, 40, 100)) +
  scale_x_date(date_labels = "%b\n%Y", date_breaks = "3 months") +
  facet_wrap(~ classifier, ncol = 1) +
  labs(x = NULL, y = "Share of true positives", tag = "a") +
  theme_bw(base_size = 10) +
  theme(panel.grid.minor = element_blank(), legend.position = "bottom",
        legend.box = "vertical", legend.margin = margin(0, 0, 0, 0))

nomes <- c(`occ_(Intercept)` = "Occupancy: intercept", occ_temp = "Occupancy: temperature",
           occ_rh = "Occupancy: humidity", occ_moon = "Occupancy: moon",
           `det_(Intercept)` = "Detection: intercept", det_bio = "Detection: BIO",
           det_aci = "Detection: ACI", `fp_(Intercept)` = "False positive: intercept")
s <- read.csv(file.path(bench, "curiango-flow-summary.csv")) |>
  filter(variable %in% names(nomes)) |>
  mutate(classifier = factor(rotulo[classifier], levels = rotulo),
         variable = factor(nomes[variable], levels = rev(nomes)))
b <- ggplot(s, aes(share_between, variable, colour = classifier, shape = classifier)) +
  geom_point(size = 2.4) +
  scale_colour_manual(values = c(Custom = "#2166ac", BirdNET = "#b35806"), name = NULL) +
  scale_shape_manual(values = c(Custom = 16, BirdNET = 17), name = NULL) +
  scale_x_continuous(limits = c(0, 1)) +
  labs(x = "Share of posterior variance\ndue to the calibration", y = NULL, tag = "b") +
  theme_bw(base_size = 10) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank())

ggsave("dev/manuscript-mee/fig2-curiango.png", a | b, width = 18, height = 11, units = "cm", dpi = 300)
