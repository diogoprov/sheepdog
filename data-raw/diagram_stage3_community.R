# =============================================================================
# diagram_stage3_community.R
#
# Figura 5 do indice de referencia: as matrizes de comunidade e, a parte, a
# saida para os modelos de ocupacao. Baseada na figura de Larissa S. M. Sugai.
# Uso: rode a partir da raiz do repositorio.
# =============================================================================
source("data-raw/diagram_style.R")

save_diagram(paste0('digraph s3 {', diagram_header("Stage 3 and occupancy: what comes after the histories"), '
  hist [label = "Nightly histories\ndetection_history(), history_draws()\nor threshold_history() (empirical route)", shape = note,
        fillcolor = "#ffffff", color = "#b8b8b8"]
  val [label = "validation_by_clip.csv", shape = note, fillcolor = "#ffffff", color = "#b8b8b8"]

  subgraph cluster_com {
    label = "Stage 3. Community matrices"; labeljust = "l"
    ', stage_cluster("s3"), '
    cell [label = "cell_status()\nreliable, probably_absent or unreliable\n(needs a calibration)"]
    core [label = "suggest_core_species()\nthe final choice is yours"]
    mat [label = "community_matrices(), community_matrices_draws()\nbuild_community_matrices()\nk_min, min_nights_month; frequency, counts, effort, trials"]
    ana [label = "vegan or gllvm", fillcolor = "#eeeeee", color = "#9a9a9a"]
  }

  subgraph cluster_occ {
    label = "Occupancy with false positives"; labeljust = "l"
    ', stage_cluster("occ"), '
    exp1 [label = "Threshold route\nexport_occupancy_data() without fit"]
    exp2 [label = "Draws route (brms)\nexport_occupancy_data(fit = ), occasion_draws()"]
    agg [label = "crywolf\nfp_aggregate(threshold = )\none model", fillcolor = "#eeeeee", color = "#9a9a9a"]
    mc [label = "crywolf\nfp_draws_data(), fp_occu_mc()\none fit per draw, pooled", fillcolor = "#eeeeee", color = "#9a9a9a"]
  }

  hist -> cell -> core -> mat -> ana
  hist -> mat
  val -> exp1; val -> exp2
  exp1 -> agg; exp2 -> mc
}'), "stage3_community", width = 1600)
