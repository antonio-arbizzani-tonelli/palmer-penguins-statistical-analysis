# Run from the repository root with: Rscript scripts/run_all.R

scripts <- c(
  "scripts/01_prepare_data.R",
  "scripts/02_exploration_and_linear_model.R",
  "scripts/03_validation_and_anova.R",
  "scripts/04_species_classification.R"
)

for (script in scripts) {
  message("\nRunning ", script)
  source(script, echo = FALSE)
}

message("\nAnalysis complete. Figures are in output/figures and tables are in output/tables.")
