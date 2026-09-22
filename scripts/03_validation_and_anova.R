source("scripts/00_utils.R")

check_dependencies()
create_output_directories()

library(dplyr)
library(ggplot2)

penguins <- read_analysis_data()

# Hold-out validation and polynomial complexity --------------------------------

set.seed(5)
training_index <- sample(seq_len(nrow(penguins)), size = 260)
regression_data <- penguins |> dplyr::select(flipper_length_mm, body_mass_g)
training_data <- regression_data[training_index, ]
test_data <- regression_data[-training_index, ]

linear_fit <- lm(body_mass_g ~ flipper_length_mm, data = training_data)
holdout_plot <- ggplot() +
  geom_point(data = training_data, aes(flipper_length_mm, body_mass_g, colour = "Training set"), alpha = 0.7) +
  geom_point(data = test_data, aes(flipper_length_mm, body_mass_g, colour = "Test set"), alpha = 0.7) +
  geom_abline(intercept = coef(linear_fit)[1], slope = coef(linear_fit)[2], colour = "grey25", linewidth = 0.9) +
  scale_colour_manual(values = c(
    "Training set" = PROJECT_COLORS[["ink"]],
    "Test set" = PROJECT_COLORS[["coral"]]
  )) +
  labs(title = "Hold-out split for flipper-length regression", x = "Flipper length (mm)", y = "Body mass (g)", colour = NULL) +
  theme_project()
save_ggplot(holdout_plot, "10_holdout_split.png")

polynomial_metrics <- lapply(1:6, function(degree) {
  model <- lm(body_mass_g ~ poly(flipper_length_mm, degree = degree, raw = TRUE), data = training_data)
  data.frame(
    degree = degree,
    train_mse = mean(residuals(model)^2),
    test_mse = mean((test_data$body_mass_g - predict(model, newdata = test_data))^2)
  )
}) |> dplyr::bind_rows()

polynomial_long <- polynomial_metrics |>
  tidyr::pivot_longer(-degree, names_to = "sample", values_to = "mse") |>
  dplyr::mutate(sample = dplyr::recode(sample, train_mse = "Training MSE", test_mse = "Test MSE"))

mse_plot <- ggplot(polynomial_long, aes(degree, mse, colour = sample)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 1:6) +
  labs(title = "Polynomial regression error by degree", x = "Polynomial degree", y = "Mean squared error", colour = NULL) +
  theme_project()
save_ggplot(mse_plot, "11_holdout_mse_by_degree.png")
readr::write_csv(polynomial_metrics, "output/tables/holdout_polynomial_mse.csv")

# Cross-validation --------------------------------------------------------------

loocv_mse <- numeric(6)
kfold_mse <- numeric(6)
training_mse <- numeric(6)

set.seed(5)
for (degree in 1:6) {
  model <- glm(
    body_mass_g ~ poly(flipper_length_mm, degree = degree, raw = TRUE),
    data = regression_data
  )
  loocv_mse[degree] <- boot::cv.glm(regression_data, model)$delta[1]
  kfold_mse[degree] <- boot::cv.glm(regression_data, model, K = 10)$delta[1]
  training_mse[degree] <- mean(residuals(model)^2)
}

cv_results <- data.frame(
  degree = 1:6,
  training_mse = training_mse,
  loocv_mse = loocv_mse,
  ten_fold_mse = kfold_mse
)
readr::write_csv(cv_results, "output/tables/polynomial_cross_validation.csv")

cv_long <- cv_results |>
  tidyr::pivot_longer(-degree, names_to = "estimate", values_to = "mse") |>
  dplyr::mutate(estimate = dplyr::recode(
    estimate,
    training_mse = "Training MSE",
    loocv_mse = "LOOCV MSE",
    ten_fold_mse = "10-fold CV MSE"
  ))

cv_plot <- ggplot(cv_long, aes(degree, mse, colour = estimate)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 1:6) +
  labs(title = "Cross-validation error by polynomial degree", x = "Polynomial degree", y = "Mean squared error", colour = NULL) +
  theme_project()
save_ggplot(cv_plot, "12_cross_validation_by_degree.png")

# Progressive model selection shown in the presentation ------------------------

ordered_predictors <- c(
  "flipper_length_mm", "culmen_length_mm", "culmen_depth_mm", "species", "sex"
)
predictor_labels <- c("Flipper length", "Culmen length", "Culmen depth", "Species", "Sex")
set.seed(5)
progressive_cv <- lapply(seq_along(ordered_predictors), function(step_number) {
  predictors <- ordered_predictors[seq_len(step_number)]
  model <- glm(reformulate(predictors, response = "body_mass_g"), data = penguins)
  data.frame(
    step = step_number,
    included_predictors = paste(predictors, collapse = " + "),
    ten_fold_cv_mse = boot::cv.glm(penguins, model, K = 10)$delta[1]
  )
}) |> dplyr::bind_rows()
readr::write_csv(progressive_cv, "output/tables/progressive_model_cv_mse.csv")

progressive_plot <- ggplot(progressive_cv, aes(step, ten_fold_cv_mse)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = progressive_cv$step, labels = predictor_labels) +
  labs(title = "Cross-validation error for progressively larger models",
       x = "Predictor added at each step", y = "10-fold CV mean squared error") +
  theme_project() +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))
save_ggplot(progressive_plot, "13_progressive_model_cv_mse.png", width = 11, height = 7)

progressive_rmse_plot <- progressive_cv |>
  dplyr::mutate(
    predictor = factor(predictor_labels, levels = predictor_labels),
    rmse = sqrt(ten_fold_cv_mse),
    group = ifelse(step < 4, "Morphology", "Species and sex")
  ) |>
  ggplot(aes(predictor, rmse, fill = group)) +
  geom_col(width = 0.7, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.0f g", rmse)), vjust = -0.35, fontface = "bold", size = 5) +
  geom_text(
    aes(y = 20, label = sprintf("MSE %.0fk", ten_fold_cv_mse / 1000)),
    colour = PROJECT_COLORS[["slate"]],
    size = 3.8
  ) +
  scale_fill_manual(values = c(
    "Morphology" = "#E3B5AA",
    "Species and sex" = PROJECT_COLORS[["coral"]]
  )) +
  coord_cartesian(ylim = c(0, 440), clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_project(base_size = 13) +
  theme(
    axis.text.y = element_blank(),
    axis.ticks = element_blank(),
    panel.grid = element_blank(),
    axis.text.x = element_text(face = "bold"),
    plot.margin = margin(10, 16, 6, 16)
  )
save_ggplot(progressive_rmse_plot, "13_progressive_model_cv_rmse.png", width = 15, height = 3.75)

# Two-way ANOVA ----------------------------------------------------------------

anova_model <- aov(body_mass_g ~ species * sex, data = penguins)
write_model_summary(anova_model, "two_way_anova.txt")

save_base_plot("14_anova_interaction_plots.png", function() {
  par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))
  with(penguins, interaction.plot(sex, species, body_mass_g, fun = mean, type = "b",
                                  pch = c(16, 17, 15), lty = 1:3, col = unname(SPECIES_COLORS),
                                  legend = TRUE, xlab = "Sex", ylab = "Mean body mass (g)",
                                  main = "Species effect across sex"))
  with(penguins, interaction.plot(species, sex, body_mass_g, fun = mean, type = "b",
                                  pch = c(16, 17), lty = 1:2, col = unname(SEX_COLORS),
                                  legend = TRUE, xlab = "Species", ylab = "Mean body mass (g)",
                                  main = "Sex effect across species"))
})

body_mass_boxplot <- ggplot(penguins, aes(species, body_mass_g, fill = species)) +
  geom_boxplot(width = 0.65, outlier.alpha = 0.55) +
  scale_fill_manual(values = SPECIES_COLORS) +
  labs(title = "Body mass by species", x = "Species", y = "Body mass (g)") +
  theme_project() +
  theme(legend.position = "none")
save_ggplot(body_mass_boxplot, "15_body_mass_by_species.png")

body_mass_sex_plot <- ggplot(penguins, aes(sex, body_mass_g, fill = sex)) +
  geom_boxplot(width = 0.65, outlier.alpha = 0.55) +
  scale_fill_manual(values = SEX_COLORS) +
  labs(title = "Body mass by sex", x = "Sex", y = "Body mass (g)") +
  theme_project() +
  theme(legend.position = "none")
save_ggplot(body_mass_sex_plot, "15_body_mass_by_sex.png")

body_mass_group_plot <- ggplot(penguins, aes(interaction(species, sex), body_mass_g, fill = species)) +
  geom_boxplot(outlier.alpha = 0.55) +
  scale_fill_manual(values = SPECIES_COLORS) +
  labs(title = "Body mass by sex and species", x = "Species and sex", y = "Body mass (g)") +
  theme_project() +
  theme(axis.text.x = element_text(angle = 25, hjust = 1))
save_ggplot(body_mass_group_plot, "16_body_mass_by_sex_and_species.png")

save_base_plot("17_anova_assumptions.png", function() {
  par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))
  qqnorm(residuals(anova_model), pch = 16, cex = 0.7, main = "ANOVA residual Q-Q plot")
  qqline(residuals(anova_model), col = "firebrick", lwd = 2)
  plot(fitted(anova_model), residuals(anova_model), pch = 16, cex = 0.7,
       xlab = "Fitted body mass (g)", ylab = "Residuals", main = "ANOVA residuals versus fitted")
  abline(h = 0, col = "firebrick", lty = 2)
})

anova_group_model <- aov(body_mass_g ~ interaction(species, sex), data = penguins)
tukey_results <- TukeyHSD(anova_group_model)
capture.output(tukey_results, file = "output/tables/tukey_hsd.txt")
readr::write_csv(
  data.frame(comparison = rownames(tukey_results[[1]]), tukey_results[[1]], row.names = NULL),
  "output/tables/tukey_hsd.csv"
)

capture.output(
  list(
    shapiro_wilk = shapiro.test(residuals(anova_model)),
    levene_test = car::leveneTest(body_mass_g ~ interaction(species, sex), data = penguins)
  ),
  file = "output/tables/anova_assumption_tests.txt"
)
