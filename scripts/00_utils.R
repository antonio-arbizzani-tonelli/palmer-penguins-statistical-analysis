# Shared utilities for the penguin analysis pipeline.

required_packages <- c(
  "boot", "car", "corrplot", "dplyr", "GGally", "ggplot2", "pROC", "readr", "tidyr"
)

PROJECT_COLORS <- c(
  ink = "#202C35",
  slate = "#516674",
  ice = "#AFC8D7",
  pale_ice = "#E7F0F4",
  coral = "#C86C5A"
)

SPECIES_COLORS <- c(
  Adelie = PROJECT_COLORS[["ink"]],
  Chinstrap = PROJECT_COLORS[["coral"]],
  Gentoo = PROJECT_COLORS[["ice"]]
)

SEX_COLORS <- c(
  FEMALE = PROJECT_COLORS[["ice"]],
  MALE = PROJECT_COLORS[["coral"]]
)

check_dependencies <- function() {
  missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

  if (length(missing_packages) > 0) {
    stop(
      "Missing required packages: ",
      paste(missing_packages, collapse = ", "),
      ". Install them with install.packages(...), then rerun the pipeline.",
      call. = FALSE
    )
  }
}

create_output_directories <- function() {
  directories <- c("data/processed", "output/figures", "output/tables")
  invisible(lapply(directories, dir.create, recursive = TRUE, showWarnings = FALSE))
}

save_ggplot <- function(plot_object, filename, width = 10, height = 7, dpi = 300) {
  ggplot2::ggsave(
    filename = file.path("output/figures", filename),
    plot = plot_object,
    width = width,
    height = height,
    dpi = dpi,
    bg = "white"
  )
}

save_base_plot <- function(filename, plot_function, width = 1800, height = 1200, res = 180) {
  grDevices::png(
    filename = file.path("output/figures", filename),
    width = width,
    height = height,
    res = res
  )
  on.exit(grDevices::dev.off(), add = TRUE)
  plot_function()
}

write_model_summary <- function(model, filename) {
  capture.output(summary(model), file = file.path("output/tables", filename))
}

theme_project <- function(base_size = 13) {
  ggplot2::theme_minimal(base_size = base_size, base_family = "sans") +
    ggplot2::theme(
      plot.title = ggplot2::element_text(
        face = "bold",
        colour = PROJECT_COLORS[["ink"]],
        margin = ggplot2::margin(b = 8)
      ),
      plot.subtitle = ggplot2::element_text(
        colour = PROJECT_COLORS[["slate"]],
        margin = ggplot2::margin(b = 10)
      ),
      axis.title = ggplot2::element_text(colour = PROJECT_COLORS[["ink"]]),
      axis.text = ggplot2::element_text(colour = PROJECT_COLORS[["slate"]]),
      legend.text = ggplot2::element_text(colour = PROJECT_COLORS[["slate"]]),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = "#D4DDE2", linewidth = 0.3),
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA)
    )
}

read_analysis_data <- function() {
  readr::read_csv("data/processed/penguins_analysis.csv", show_col_types = FALSE) |>
    dplyr::mutate(
      species = factor(species, levels = c("Adelie", "Chinstrap", "Gentoo")),
      island = factor(island),
      clutch_completion = factor(clutch_completion),
      sex = factor(sex)
    )
}
