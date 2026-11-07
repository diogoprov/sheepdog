# Figures of the reference index

The stage figures of the pkgdown site, based on the figures drawn by Larissa S. M. Sugai. Run each script from the repository root.

- `schematic_*.R`: small drawings, one idea each, from the icons in `schematic_icons.R`.
- `diagram_stage*.R`: Graphviz diagrams, used where there is a decision to follow, with the style in `diagram_style.R`.
- `plot_routes.R`: ggplot2 figures on simulated data, for the reference index and `vignettes/articles/choosing-a-route.Rmd`.
- `plot_scores.R`: the overlap of the scores of true and false detections.
- `plot_occupancy.R`, `occupancy_*.dot`: occupancy with false positives, adapted from the article "How crywolf works".
- `copy_figures.R`: copies the figures to the vignettes and articles; run it after redrawing any of them.
- `pkgdown/assets/cheatsheets/sheepdog-illustrated-guide.pdf`: the five figures of Larissa S. M. Sugai, unchanged, from `man/figures/` of commit `1036ff2` of her fork, joined with ImageMagick at 280 dpi. The thumbnails come from `pdftoppm -r 44`.
- `cheatsheet/`: the HTML of the cheat sheet, and `build.R`, which prints it to `pkgdown/assets/cheatsheets/sheepdog-cheatsheet.pdf` with Google Chrome.

The PNGs go to `pkgdown/assets/figures/`, and the copies to `vignettes/articles/figures/` stay outside the built package. The copies in `vignettes/figures/` go into it, because the vignettes use them.
