# =============================================================================
# diagram_stage1_diagnostic.R
#
# Figura 2 do indice de referencia: o limiar empirico e o do modelo, na ordem
# em que review_support() atribui o diagnostico (R/post_validation.R), e a
# comparacao dos dois. Baseada na figura de Larissa S. M. Sugai.
# Uso: rode a partir da raiz do repositorio.
# =============================================================================
source("data-raw/diagram_style.R")

decisao <- 'shape = diamond, style = "filled", margin = "0.02,0.02"'

save_diagram(paste0('digraph diag {', diagram_header("After the review: the empirical and the model-based thresholds"), '
  val [label = "validation_by_clip.csv\nmanifest + verdict per clip", shape = note,
       fillcolor = "#ffffff", color = "#b8b8b8"]

  subgraph cluster_a {
    label = "A. Empirical threshold"
    ', stage_cluster("s1"), '
    rs [label = "review_support()\nsuggest_thresholds() in each site x species cell"]
    d1 [label = "any clip\nreviewed?", ', decisao, ', fillcolor = "#c8def3"]
    d2 [label = "target\nreached?", ', decisao, ', fillcolor = "#c8def3"]
    d3 [label = "high-score\ndetections left?", ', decisao, ', fillcolor = "#c8def3"]
    d4 [label = "precision at\nhigh scores\n>= min_precision?", ', decisao, ', fillcolor = "#c8def3"]
    nr [label = "\\"not reviewed\\"\ndraw clips for the cell"]
    re [label = "\\"reached\\"\nthe cell has a threshold", penwidth = 2]
    ex [label = "\\"exhausted\\"\nkeep the clips; the model may\nstill give a threshold"]
    un [label = "\\"unreliable\\"\nthe classifier is the limit:\nretraining"]
    mo [label = "\\"review more\\"\nselect_clips(previous = ),\nthen combine_rounds()"]
  }

  subgraph cluster_b {
    label = "B. Model-based threshold"
    ', stage_cluster("s2"), '
    cal [label = "calibrate()\ncompare_calibration_models(), fit_calibration()"]
    q [label = "calibration_quality()\nok?", ', decisao, ', fillcolor = "#f9e3ae"]
    thr [label = "calibrated_thresholds()\nrule = \\"precision\\" or \\"probability\\""]
    poor [label = "\\"poor\\" or \\"insufficient\\"\nmore clips, a covariate or another model;\nor keep the empirical threshold"]
  }

  cmp [label = "compare_thresholds()\nthresholds_compared.csv\nflag: agree, disagree, model_only, empirical_only, none",
       fillcolor = "#f4f4f4", color = "#9a9a9a"]

  val -> rs; val -> cal
  rs -> d1
  d1 -> nr [label = " no"]; d1 -> d2 [label = " yes"]
  d2 -> re [label = " yes"]; d2 -> d3 [label = " no"]
  d3 -> ex [label = " no"]; d3 -> d4 [label = " yes"]
  d4 -> un [label = " no"]; d4 -> mo [label = " yes"]
  mo -> val [style = dashed, constraint = false, label = " new round"]
  cal -> q; q -> thr [label = " yes"]; q -> poor [label = " no"]
  re -> cmp; thr -> cmp
}'), "stage1_diagnostic")
