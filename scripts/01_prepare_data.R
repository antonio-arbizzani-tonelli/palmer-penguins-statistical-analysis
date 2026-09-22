source("scripts/00_utils.R")

check_dependencies()
create_output_directories()

raw_penguins <- readr::read_csv("data/raw/penguins.csv", show_col_types = FALSE)

penguins <- raw_penguins |>
  dplyr::select(-dplyr::matches("^\\.\\.\\.1$")) |>
  dplyr::transmute(
    species = factor(sub(" .*", "", Species), levels = c("Adelie", "Chinstrap", "Gentoo")),
    island = factor(Island),
    clutch_completion = factor(`Clutch Completion`),
    culmen_length_mm = `Culmen Length (mm)`,
    culmen_depth_mm = `Culmen Depth (mm)`,
    flipper_length_mm = `Flipper Length (mm)`,
    body_mass_g = `Body Mass (g)`,
    sex = factor(Sex),
    delta_15n = `Delta 15 N (o/oo)`,
    delta_13c = `Delta 13 C (o/oo)`
  ) |>
  dplyr::filter(dplyr::if_all(dplyr::everything(), ~ !is.na(.x)))

if (nrow(penguins) != 324) {
  warning("The cleaned dataset has ", nrow(penguins), " rows; the presentation used 324 complete observations.")
}

readr::write_csv(penguins, "data/processed/penguins_analysis.csv")

dataset_summary <- penguins |>
  dplyr::group_by(species, sex) |>
  dplyr::summarise(
    observations = dplyr::n(),
    mean_body_mass_g = mean(body_mass_g),
    sd_body_mass_g = sd(body_mass_g),
    .groups = "drop"
  )

readr::write_csv(dataset_summary, "output/tables/dataset_summary.csv")

message("Prepared ", nrow(penguins), " complete observations in data/processed/penguins_analysis.csv")
