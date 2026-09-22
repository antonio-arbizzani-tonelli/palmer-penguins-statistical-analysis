source("scripts/00_utils.R")

check_dependencies()
create_output_directories()

library(dplyr)
library(ggplot2)

penguins <- read_analysis_data()
numeric_variables <- penguins |>
  dplyr::select(culmen_length_mm, culmen_depth_mm, flipper_length_mm, body_mass_g)

correlation_matrix <- cor(numeric_variables)
readr::write_csv(
  data.frame(variable = rownames(correlation_matrix), correlation_matrix, row.names = NULL),
  "output/tables/correlation_matrix.csv"
)

save_base_plot("01_correlation_matrix.png", function() {
  par(mfrow = c(1, 2), mar = c(1, 1, 3, 1))
  corrplot::corrplot(correlation_matrix, method = "number", type = "upper", tl.col = "black")
  title("Correlation coefficients")
  corrplot::corrplot(correlation_matrix, method = "color", type = "upper", tl.col = "black")
  title("Correlation heat map")
})

pair_plot <- GGally::ggpairs(
  numeric_variables,
  lower = list(continuous = GGally::wrap("points", alpha = 0.5, size = 0.7)),
  title = "Relationships among morphological measurements and body mass"
)
save_ggplot(pair_plot, "02_pair_plot_overall.png", width = 12, height = 10)

pair_plot_sex <- GGally::ggpairs(
  penguins |> dplyr::select(sex, dplyr::all_of(names(numeric_variables))),
  mapping = aes(colour = sex, alpha = 0.55),
  lower = list(continuous = GGally::wrap("points", size = 0.7)),
  title = "Relationships by sex"
)
save_ggplot(pair_plot_sex, "03_pair_plot_by_sex.png", width = 12, height = 10)

pair_plot_species <- GGally::ggpairs(
  penguins |> dplyr::select(species, dplyr::all_of(names(numeric_variables))),
  mapping = aes(colour = species, alpha = 0.55),
  lower = list(continuous = GGally::wrap("points", size = 0.7)),
  title = "Relationships by species"
)
save_ggplot(pair_plot_species, "04_pair_plot_by_species.png", width = 12, height = 10)

full_model <- lm(
  body_mass_g ~ species + island + clutch_completion + culmen_length_mm +
    culmen_depth_mm + flipper_length_mm + sex,
  data = penguins
)
write_model_summary(full_model, "full_linear_model.txt")

bic_model <- step(full_model, direction = "backward", k = log(nrow(penguins)), trace = 0)
write_model_summary(bic_model, "bic_selected_linear_model.txt")

model_comparison <- data.frame(
  model = c("Full model", "BIC-selected model"),
  AIC = c(AIC(full_model), AIC(bic_model)),
  BIC = c(BIC(full_model), BIC(bic_model)),
  adjusted_r_squared = c(summary(full_model)$adj.r.squared, summary(bic_model)$adj.r.squared)
)
readr::write_csv(model_comparison, "output/tables/linear_model_comparison.csv")

leverage <- hatvalues(full_model)
standardized_residuals <- rstandard(full_model)
cook_distance <- cooks.distance(full_model)
leverage_cutoff <- 2 * full_model$rank / nrow(penguins)
cook_cutoff <- 4 / (nrow(penguins) - full_model$rank)

influence_table <- penguins |>
  dplyr::mutate(
    observation = dplyr::row_number(),
    fitted_body_mass_g = fitted(full_model),
    leverage = leverage,
    standardized_residual = standardized_residuals,
    cooks_distance = cook_distance,
    high_leverage = leverage > leverage_cutoff,
    influential_by_cook = cook_distance > cook_cutoff,
    residual_outlier = abs(standardized_residual) > 2
  ) |>
  dplyr::filter(high_leverage | influential_by_cook | residual_outlier)
readr::write_csv(influence_table, "output/tables/influential_observations.csv")

save_base_plot("05_influence_diagnostics.png", function() {
  par(mfrow = c(1, 3), mar = c(4, 4, 3, 1))

  plot(fitted(full_model), cook_distance, pch = 16, cex = 0.7,
       xlab = "Fitted body mass (g)", ylab = "Cook's distance", main = "Cook's distance")
  abline(h = cook_cutoff, col = "darkgreen", lty = 2)
  points(fitted(full_model)[cook_distance > cook_cutoff], cook_distance[cook_distance > cook_cutoff],
         col = "darkgreen", pch = 16)

  plot(fitted(full_model), standardized_residuals, pch = 16, cex = 0.7,
       xlab = "Fitted body mass (g)", ylab = "Standardized residual", main = "Standardized residuals")
  abline(h = c(-2, 2), col = "firebrick", lty = 2)
  points(fitted(full_model)[abs(standardized_residuals) > 2], standardized_residuals[abs(standardized_residuals) > 2],
         col = "firebrick", pch = 16)

  plot(fitted(full_model), leverage, pch = 16, cex = 0.7,
       xlab = "Fitted body mass (g)", ylab = "Leverage", main = "Leverage")
  abline(h = leverage_cutoff, col = "orange3", lty = 2)
  points(fitted(full_model)[leverage > leverage_cutoff], leverage[leverage > leverage_cutoff],
         col = "orange3", pch = 16)
})

save_base_plot("06_linear_model_assumptions.png", function() {
  par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))
  plot(fitted(full_model), residuals(full_model), pch = 16, cex = 0.7,
       xlab = "Fitted body mass (g)", ylab = "Residuals", main = "Residuals versus fitted values")
  abline(h = 0, col = "firebrick", lty = 2)
  qqnorm(residuals(full_model), pch = 16, cex = 0.7, main = "Normal Q-Q plot")
  qqline(residuals(full_model), col = "firebrick", lwd = 2)
})

capture.output(shapiro.test(residuals(full_model)), file = "output/tables/shapiro_test_linear_model.txt")

make_interval_plot <- function(predictor, x_label, filename) {
  model <- lm(reformulate(predictor, response = "body_mass_g"), data = penguins)
  grid <- seq(min(penguins[[predictor]]), max(penguins[[predictor]]), length.out = 200)
  new_data <- setNames(data.frame(grid), predictor)
  confidence <- as.data.frame(predict(model, newdata = new_data, interval = "confidence"))
  prediction <- as.data.frame(predict(model, newdata = new_data, interval = "prediction"))
  curve_data <- data.frame(
    x = grid, fit = confidence$fit, confidence_lower = confidence$lwr,
    confidence_upper = confidence$upr, prediction_lower = prediction$lwr,
    prediction_upper = prediction$upr
  )

  interval_plot <- ggplot(penguins, aes(x = .data[[predictor]], y = body_mass_g)) +
    geom_point(alpha = 0.65, size = 1.5) +
    geom_ribbon(data = curve_data, aes(x = x, ymin = prediction_lower, ymax = prediction_upper),
                inherit.aes = FALSE, fill = PROJECT_COLORS[["ice"]], alpha = 0.25) +
    geom_ribbon(data = curve_data, aes(x = x, ymin = confidence_lower, ymax = confidence_upper),
                inherit.aes = FALSE, fill = PROJECT_COLORS[["ice"]], alpha = 0.5) +
    geom_line(data = curve_data, aes(x = x, y = fit), inherit.aes = FALSE,
              colour = PROJECT_COLORS[["ink"]], linewidth = 0.9) +
    labs(
      title = paste("Body mass versus", x_label),
      subtitle = "Dark band: confidence interval for the mean. Light band: prediction interval.",
      x = x_label, y = "Body mass (g)"
    ) +
    theme_project()

  save_ggplot(interval_plot, filename)
  write_model_summary(model, paste0(tools::file_path_sans_ext(filename), "_simple_model.txt"))
}

make_interval_plot("flipper_length_mm", "Flipper length (mm)", "07_flipper_intervals.png")
make_interval_plot("culmen_length_mm", "Culmen length (mm)", "08_culmen_length_intervals.png")
make_interval_plot("culmen_depth_mm", "Culmen depth (mm)", "09_culmen_depth_intervals.png")
