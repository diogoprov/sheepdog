# Appendix S2: redraw review samples from the annotated Curiango minutes
# under the designs of select_clips(), whose inclusion probabilities are known.
#
# The 521 minutes of ct01+ct02 with a custom-classifier score >= 0.1 and a
# verdict by ear form a finite population. Each design draws about 120 clips
# from it, 200 times. Estimands, defined in that population:
#   * share of true positives among the predictions, with weights
#     1 / inclusion_prob (Hajek) and without weights;
#   * probability of a true positive at scores 0.15, 0.25 and 0.5, from a
#     logistic regression on the logit of the score (glm, the global
#     calibration model of compare_calibration_models(), fitted by maximum
#     likelihood for speed).
# "top_scores" is not a select_clips() design: with one minute per
# site x night x hour, "top" would keep every minute. It takes the 17
# highest scores of each recorder, the usual way of reviewing top clips, and
# has no inclusion probabilities (weights of 1).
# Run from the repository root:
#   Rscript dev/manuscript-mee/appS2-subsampling.R
suppressPackageStartupMessages({
  library(dplyr); library(readr); library(tidyr); library(ggplot2)
  devtools::load_all(quiet = TRUE)
})

val <- read_csv("dev/benchmarks/results/ct12/original-export/custom/validation.csv",
                show_col_types = FALSE) |>
  filter(sampling_mode == "random_detections")
stopifnot(nrow(val) == 521)

pred <- val |>
  transmute(site, species_code = "Nyctidromus albicollis_nyc-alb", confidence,
            begin_path = paste0("/audio/", site, "/", occasion_id, ".wav"),
            file_offset = 0, begin_time = 0, end_time = 3)
truth_tp <- select(val, occasion_id, tp)

logit <- function(p) qlogis(pmin(pmax(p, 1e-4), 1 - 1e-4))
at <- c(0.15, 0.25, 0.5)
calib <- function(d) {
  m <- suppressWarnings(glm(tp ~ logit(confidence), family = binomial, data = d))
  unname(predict(m, data.frame(confidence = at), type = "response"))
}
truth <- tibble(estimand = c("share_tp", "share_tp_unweighted",
                             paste0("p_tp_at_", at)),
                true = c(mean(val$tp), mean(val$tp), calib(val)))

designs <- list(
  random_detections = list(sampling_mode = "random_detections",
                           strata = "site_species", n_top = 17,
                           occasion_unit = "minute"),
  score_bands = list(sampling_mode = "score_bands", strata = "species",
                     score_breaks = c(0.1, 0.2, 0.3, 1), n_top = 40)
)

draw <- function(design, seed) {
  if (design == "top_scores") {
    m <- val |> group_by(site) |> slice_max(confidence, n = 17, with_ties = FALSE) |>
      ungroup() |> mutate(inclusion_prob = NA_real_)
    return(estimate(design, seed, m))
  }
  args <- c(list(detections = pred, threshold = 0.1, min_confidence = 0.1,
                 seed = seed), designs[[design]])
  m <- suppressMessages(suppressWarnings(do.call(select_clips, args)))
  m <- m |>
    mutate(occasion_id = tools::file_path_sans_ext(basename(source_audio))) |>
    distinct(occasion_id, .keep_all = TRUE) |>
    inner_join(truth_tp, by = "occasion_id")
  estimate(design, seed, m)
}
estimate <- function(design, seed, m) {
  w <- if ("inclusion_prob" %in% names(m) && !all(is.na(m$inclusion_prob)))
    1 / m$inclusion_prob else rep(1, nrow(m))
  tibble(design, seed, n = nrow(m), n_tp = sum(m$tp),
         estimand = truth$estimand,
         estimate = c(sum(w * m$tp) / sum(w), mean(m$tp), calib(m)))
}

reps <- 200
res <- bind_rows(
  draw("top_scores", NA),
  bind_rows(lapply(names(designs), function(d)
    bind_rows(lapply(seq_len(reps), function(s) draw(d, s))))))

out <- res |>
  left_join(truth, by = "estimand") |>
  group_by(design, estimand, true) |>
  summarise(n_clips = mean(n), n_tp = mean(n_tp),
            mean = mean(estimate), bias = mean(estimate - true),
            rel_bias = bias / first(true),
            rmse = sqrt(mean((estimate - true)^2)),
            q05 = quantile(estimate, 0.05), q95 = quantile(estimate, 0.95),
            .groups = "drop")
dir.create("dev/manuscript-mee/appS2", showWarnings = FALSE)
write_csv(res, "dev/manuscript-mee/appS2/subsampling-reps.csv")
write_csv(out, "dev/manuscript-mee/appS2/subsampling-summary.csv")
print(out, n = Inf, width = Inf)

lab <- c(share_tp = "Share of true positives (weighted)",
         share_tp_unweighted = "Share of true positives (unweighted)",
         p_tp_at_0.15 = "P(true) at score 0.15",
         p_tp_at_0.25 = "P(true) at score 0.25",
         p_tp_at_0.5 = "P(true) at score 0.5")
g <- ggplot(res, aes(design, estimate)) +
  geom_violin(fill = "grey85", colour = NA) +
  geom_boxplot(width = 0.15, outlier.size = 0.5) +
  geom_point(data = filter(res, design == "top_scores"), shape = 4, size = 3) +
  geom_hline(data = truth, aes(yintercept = true), linetype = 2,
             colour = "#B2182B") +
  facet_wrap(~ factor(estimand, names(lab)), ncol = 2, scales = "free_y", labeller = as_labeller(lab)) +
  labs(x = NULL, y = "Estimate over 200 draws") +
  theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank())
ggsave("dev/manuscript-mee/appS2/subsampling.png", g, width = 7, height = 5.5,
       dpi = 300)
