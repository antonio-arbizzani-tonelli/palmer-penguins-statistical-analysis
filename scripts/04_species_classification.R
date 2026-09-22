source("scripts/00_utils.R")

check_dependencies()
create_output_directories()

library(dplyr)
library(ggplot2)

penguins <- read_analysis_data()
classification_data <- penguins |>
  dplyr::filter(species %in% c("Adelie", "Chinstrap")) |>
  droplevels()

# The full model is retained to document the separation/convergence issue
# discussed in the presentation. The bivariate model below is used for
# interpretable classification and diagnostic plots.
suppressWarnings(full_logistic_model <- glm(
  species ~ island + clutch_completion + culmen_length_mm + culmen_depth_mm +
    flipper_length_mm + body_mass_g + sex,
  family = binomial(),
  data = classification_data
))
write_model_summary(full_logistic_model, "full_logistic_model.txt")

bill_only_model <- glm(species ~ culmen_length_mm, family = binomial(), data = classification_data)
bivariate_model <- glm(
  species ~ culmen_length_mm + flipper_length_mm,
  family = binomial(),
  data = classification_data
)
write_model_summary(bill_only_model, "bill_only_logistic_model.txt")
write_model_summary(bivariate_model, "bivariate_logistic_model.txt")

model_lrt <- anova(bill_only_model, bivariate_model, test = "LRT")
capture.output(model_lrt, file = "output/tables/logistic_model_lrt.txt")

bill_grid <- data.frame(culmen_length_mm = seq(
  min(classification_data$culmen_length_mm),
  max(classification_data$culmen_length_mm),
  length.out = 200
))
bill_grid$predicted_probability_chinstrap <- predict(bill_only_model, newdata = bill_grid, type = "response")

bill_probability_plot <- ggplot(classification_data, aes(culmen_length_mm, as.integer(species == "Chinstrap"))) +
  geom_point(aes(colour = species), alpha = 0.65, position = position_jitter(height = 0.03)) +
  geom_line(data = bill_grid, aes(culmen_length_mm, predicted_probability_chinstrap),
            inherit.aes = FALSE, colour = PROJECT_COLORS[["ink"]], linewidth = 0.9) +
  scale_colour_manual(values = SPECIES_COLORS[c("Adelie", "Chinstrap")]) +
  scale_y_continuous(breaks = c(0, 1), labels = c("Adelie", "Chinstrap")) +
  labs(title = "Chinstrap probability from culmen length", x = "Culmen length (mm)", y = "Observed species", colour = "Species") +
  theme_project()
save_ggplot(bill_probability_plot, "18_bill_length_logistic_probability.png")

logistic_data_plot <- GGally::ggpairs(
  classification_data |>
    dplyr::select(species, culmen_length_mm, culmen_depth_mm, flipper_length_mm, body_mass_g),
  mapping = aes(colour = species, alpha = 0.6),
  lower = list(continuous = GGally::wrap("points", size = 0.8)),
  title = "Adelie and Chinstrap: morphological data inspection"
)
save_ggplot(logistic_data_plot, "18_logistic_data_inspection.png", width = 12, height = 10)

classification_data <- classification_data |>
  dplyr::mutate(
    predicted_probability_chinstrap = predict(bivariate_model, type = "response"),
    predicted_species = factor(
      ifelse(predicted_probability_chinstrap >= 0.5, "Chinstrap", "Adelie"),
      levels = c("Adelie", "Chinstrap")
    )
  )

confusion_matrix <- with(classification_data, table(observed = species, predicted = predicted_species))
readr::write_csv(
  as.data.frame.matrix(confusion_matrix) |>
    dplyr::mutate(observed = rownames(confusion_matrix), .before = 1),
  "output/tables/logistic_confusion_matrix.csv"
)

accuracy <- mean(classification_data$species == classification_data$predicted_species)
sensitivity <- confusion_matrix["Chinstrap", "Chinstrap"] / sum(confusion_matrix["Chinstrap", ])
specificity <- confusion_matrix["Adelie", "Adelie"] / sum(confusion_matrix["Adelie", ])

roc_object <- pROC::roc(
  response = classification_data$species,
  predictor = classification_data$predicted_probability_chinstrap,
  levels = c("Adelie", "Chinstrap"),
  direction = "<",
  quiet = TRUE
)
roc_coordinates <- pROC::coords(
  roc_object,
  x = "best",
  best.method = "youden",
  ret = c("threshold", "sensitivity", "specificity"),
  transpose = FALSE
)

metrics <- data.frame(
  accuracy = accuracy,
  sensitivity = sensitivity,
  specificity = specificity,
  auc = as.numeric(pROC::auc(roc_object)),
  optimal_threshold = roc_coordinates["threshold"]
)
readr::write_csv(metrics, "output/tables/logistic_performance_metrics.csv")

# Classification boundary at probability = 0.5.
coefficients <- coef(bivariate_model)
boundary_data <- data.frame(culmen_length_mm = seq(
  min(classification_data$culmen_length_mm),
  max(classification_data$culmen_length_mm),
  length.out = 200
))
boundary_data$flipper_length_mm <- -(
  coefficients["(Intercept)"] + coefficients["culmen_length_mm"] * boundary_data$culmen_length_mm
) / coefficients["flipper_length_mm"]

boundary_plot <- ggplot(classification_data, aes(culmen_length_mm, flipper_length_mm, colour = species)) +
  geom_point(alpha = 0.75) +
  geom_line(data = boundary_data, aes(culmen_length_mm, flipper_length_mm),
            inherit.aes = FALSE, colour = "grey20", linewidth = 0.9) +
  scale_colour_manual(values = SPECIES_COLORS[c("Adelie", "Chinstrap")]) +
  labs(
    title = "Logistic classification boundary",
    subtitle = "The line represents a predicted Chinstrap probability of 0.5.",
    x = "Culmen length (mm)", y = "Flipper length (mm)", colour = "Species"
  ) +
  theme_project()
save_ggplot(boundary_plot, "19_logistic_classification_boundary.png")

culmen_grid <- seq(min(classification_data$culmen_length_mm), max(classification_data$culmen_length_mm), length.out = 100)
flipper_grid <- seq(min(classification_data$flipper_length_mm), max(classification_data$flipper_length_mm), length.out = 100)
probability_grid <- expand.grid(
  culmen_length_mm = culmen_grid,
  flipper_length_mm = flipper_grid
)
probability_grid$probability_chinstrap <- predict(bivariate_model, newdata = probability_grid, type = "response")

probability_plot <- ggplot(probability_grid, aes(culmen_length_mm, flipper_length_mm, fill = probability_chinstrap)) +
  geom_raster() +
  geom_contour(
    data = probability_grid,
    aes(culmen_length_mm, flipper_length_mm, z = probability_chinstrap),
    inherit.aes = FALSE,
    colour = "white",
    breaks = c(0.25, 0.5, 0.75)
  ) +
  scale_fill_gradient(
    low = PROJECT_COLORS[["pale_ice"]],
    high = PROJECT_COLORS[["ink"]],
    name = "P(Chinstrap)"
  ) +
  labs(title = "Estimated Chinstrap probability", x = "Culmen length (mm)", y = "Flipper length (mm)") +
  theme_project()
save_ggplot(probability_plot, "20_logistic_probability_contours.png")

save_base_plot("21_logistic_probability_surface.png", function() {
  probability_matrix <- matrix(
    probability_grid$probability_chinstrap,
    nrow = length(culmen_grid),
    ncol = length(flipper_grid)
  )
  persp(
    x = culmen_grid, y = flipper_grid, z = probability_matrix,
    theta = 35, phi = 25, expand = 0.6, ticktype = "detailed",
    xlab = "Culmen length (mm)", ylab = "Flipper length (mm)", zlab = "P(Chinstrap)",
    main = "Logistic probability surface", col = "grey85", border = "grey35"
  )
})

save_base_plot("22_logistic_roc_curve.png", function() {
  plot(
    roc_object,
    col = PROJECT_COLORS[["ink"]],
    lwd = 2,
    main = sprintf("ROC curve (AUC = %.3f)", as.numeric(pROC::auc(roc_object)))
  )
})

# Hosmer-Lemeshow test calculated without an additional package.
hosmer_lemeshow <- function(observed, probabilities, groups = 10) {
  bins <- cut(
    rank(probabilities, ties.method = "first"),
    breaks = groups,
    labels = FALSE,
    include.lowest = TRUE
  )
  grouped <- data.frame(observed = observed, probabilities = probabilities, bin = bins) |>
    dplyr::group_by(bin) |>
    dplyr::summarise(
      observed_events = sum(observed),
      expected_events = sum(probabilities),
      observations = dplyr::n(),
      .groups = "drop"
    )
  grouped <- grouped |>
    dplyr::mutate(
      observed_non_events = observations - observed_events,
      expected_non_events = observations - expected_events
    )
  statistic <- sum(
    (grouped$observed_events - grouped$expected_events)^2 / grouped$expected_events +
      (grouped$observed_non_events - grouped$expected_non_events)^2 / grouped$expected_non_events
  )
  data.frame(
    statistic = statistic,
    degrees_of_freedom = groups - 2,
    p_value = pchisq(statistic, df = groups - 2, lower.tail = FALSE)
  )
}

hosmer_results <- hosmer_lemeshow(
  observed = as.integer(classification_data$species == "Chinstrap"),
  probabilities = classification_data$predicted_probability_chinstrap
)
readr::write_csv(hosmer_results, "output/tables/hosmer_lemeshow_test.csv")

odds_ratio <- exp(coef(bivariate_model))
confidence_intervals <- exp(confint.default(bivariate_model))
odds_ratio_table <- data.frame(
  term = names(odds_ratio),
  odds_ratio = unname(odds_ratio),
  lower_95 = confidence_intervals[, 1],
  upper_95 = confidence_intervals[, 2],
  row.names = NULL
)
readr::write_csv(odds_ratio_table, "output/tables/logistic_odds_ratios.csv")
