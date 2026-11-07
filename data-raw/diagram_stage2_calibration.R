# =============================================================================
# diagram_stage2_calibration.R
#
# Figura 4 do indice de referencia: ajuste, escolha, checagem e aplicacao da
# calibracao, e as tres formas de chegar ao historico noturno. Baseada na
# figura de Larissa S. M. Sugai.
# Uso: rode a partir da raiz do repositorio.
# =============================================================================
source("data-raw/diagram_style.R")

save_diagram(paste0('digraph s2 {', diagram_header("Stage 2. Calibration: from scores to nightly histories"), '
  val [label = "validation_by_clip.csv\nrandom_detections clips", shape = note,
       fillcolor = "#ffffff", color = "#b8b8b8"]

  subgraph cluster_cal {
    label = "calibrate(): one call, or step by step"
    ', stage_cluster("s2"), '
    ler [label = "read_validations()"]
    cv [label = "compare_calibration_models()\nselect_calibration_model()\nsimplest model within one SE of the best"]
    fit [label = "fit_calibration()\nengine = \\"lme4\\" or \\"brms\\""]
    q [label = "calibration_quality()\nok?", shape = diamond, style = "filled",
       fillcolor = "#f9e3ae", margin = "0.02,0.02"]
    poor [label = "\\"poor\\" or \\"insufficient\\"\nmore clips (calibration_effort()), a covariate,\nanother model, or the empirical threshold"]
    score [label = "score_detections()\nP(tp) for every detection"]
    checks [label = "engine = \\"brms\\": calibration_prior(), calibration_diagnostics(),\ncalibration_ppc(), calibration_sensitivity()"]
  }
  subgraph cluster_ways {
    label = "Three ways to a nightly history"
    ', stage_cluster("s2"), '
    w1 [label = "Way 1 (lme4 or brms)\ndetection_history(rule = \\"mean\\")"]
    w2 [label = "Way 2 (brms)\ndetection_history(rule = \\"probability\\")"]
    w3 [label = "Way 3 (brms)\nhistory_draws()\none history per posterior draw"]
    {rank = same; w1 -> w2 -> w3 [style = invis]}
  }
  next3 [label = "Community matrices", fillcolor = "#d9f2e0", color = "#8fbf9f"]
  nextocc [label = "Occupancy with false positives", fillcolor = "#efe2f8", color = "#b393c9"]

  val -> ler -> cv -> fit -> q
  fit -> checks [style = dashed]
  q -> score [label = " yes"]; q -> poor [label = " no"]
  score -> w1; score -> w2; score -> w3
  w1 -> next3; w2 -> next3; w3 -> next3
  w1 -> nextocc [style = dashed, label = " threshold route"]
  w3 -> nextocc [style = dashed, label = " draws route"]
}'), "stage2_calibration")
