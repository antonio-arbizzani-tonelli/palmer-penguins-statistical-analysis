# Presentation plan

The final presentation should be shorter than the original course deck and built around the statistical argument rather than the order in which the analyses were performed. A target of 14 to 16 main slides is appropriate. Detailed diagnostics can be moved to an appendix.

## Visual direction

The current preview establishes the basic design:

- 16:9 format;
- Aptos Display for titles and Aptos for body text;
- warm off-white background (`#F8F6F2`);
- charcoal text (`#202C35`);
- slate secondary text (`#516674`);
- ice blue for rules and secondary data (`#AFC8D7`);
- muted coral for emphasis (`#C86C5A`).

The cover can remain more informal than the analytical slides. The penguin image should appear only on the opening slide. The rest of the deck should rely on data graphics, model diagrams and short numerical callouts.

Meaningful text should normally remain at 17 points or larger. Small section labels and page numbers can be smaller, but they should not carry information that the audience needs to read during the talk.

## Figure style

Figures exported directly from R should be treated as source material rather than finished slides. Before placing them in PowerPoint:

1. remove technical variable names with underscores;
2. use the same colours as the deck;
3. reduce grid lines and unnecessary legends;
4. enlarge axis titles and labels for projection;
5. highlight the value discussed in the slide title;
6. avoid showing two charts when one chart makes the same point more clearly.

The result slides should use takeaway titles only when the evidence on the slide supports the statement. Setup slides can use direct titles such as “Dataset and variables” or “Logistic model”.

## Proposed slide sequence

### 1. Cover

**Purpose:** introduce the topic and the project team.

**Content:** title, short subtitle and the four authors on one line.

**Visual:** the selected penguin image across most of the slide, with a light editorial band for the text.

### 2. Research questions

**Purpose:** establish the two strands of the analysis.

**Content:** body-mass modelling on the left and Adelie-Chinstrap classification on the right.

**Visual:** two balanced columns. Linear regression and two-way ANOVA sit below the body-mass question; logistic regression sits below the classification question. The methods should not appear as a chronological process because they answer different questions.

### 3. Dataset and variables

**Purpose:** explain what one row represents and which variables enter the models.

**Content:** 324 complete observations, body mass as the response, three morphological measurements and the categorical variables.

**Visual:** keep the sample size as a large number, then add a compact composition chart by species. Present numerical and categorical variables as two clearly separated groups.

**Source:** `output/tables/dataset_summary.csv`.

### 4. Morphology and body mass

**Purpose:** show the strongest univariate pattern before fitting a multivariable model.

**Content:** flipper length has the largest Pearson correlation with body mass (`r = 0.88`).

**Visual:** replace the current correlation-matrix screenshot with a large scatter plot of body mass against flipper length, coloured by species. Add a small correlation callout rather than a second heatmap.

**Source:** `output/tables/correlation_matrix.csv` and the cleaned dataset.

### 5. Multivariable body-mass model

**Purpose:** introduce the full linear model and the role of each predictor group.

**Content:** species, island, clutch completion, bill measurements, flipper length and sex.

**Visual:** a compact model specification on the left and a coefficient plot with 95% confidence intervals on the right. Avoid a screenshot of the R summary.

**Source:** `output/tables/full_linear_model.txt`.

### 6. Model fit and interpretation

**Purpose:** summarise the scale of the fitted model.

**Content:** adjusted R-squared, residual standard error and the largest interpretable effects.

**Visual:** three numerical callouts supported by a coefficient plot. Coefficients for categorical variables should state their reference group.

**Source:** `output/tables/full_linear_model.txt` and `output/tables/linear_model_comparison.csv`.

### 7. Regression diagnostics

**Purpose:** show whether the model assumptions are reasonable and identify influential observations.

**Content:** residual pattern, Q-Q behaviour, leverage and Cook’s distance.

**Visual:** use two large diagnostic plots in the main slide. Move the complete influence panel and observation table to the appendix.

**Source:** `output/figures/05_influence_diagnostics.png`, `output/figures/06_linear_model_assumptions.png` and `output/tables/influential_observations.csv`.

### 8. Model selection

**Purpose:** compare the full model with the BIC-selected alternative.

**Content:** retained predictors, BIC and adjusted R-squared.

**Visual:** a two-row comparison table with the selected variables highlighted. The conclusion should focus on whether simplification changes explanatory performance.

**Source:** `output/tables/linear_model_comparison.csv` and `output/tables/bic_selected_linear_model.txt`.

### 9. Prediction intervals

**Purpose:** distinguish uncertainty in the mean response from uncertainty for an individual penguin.

**Content:** confidence and prediction bands for the main continuous predictor.

**Visual:** use the flipper-length interval plot as the main figure. Bill-length and bill-depth versions belong in the appendix.

**Source:** `output/figures/07_flipper_intervals.png`.

### 10. Polynomial complexity and validation

**Purpose:** show how model complexity affects out-of-sample error.

**Content:** training, hold-out, LOOCV and 10-fold cross-validation errors across polynomial degrees.

**Visual:** one line chart with consistent colours and a clear marker on the preferred degree. Avoid showing separate charts with repeated axes unless the estimates differ materially.

**Source:** `output/tables/holdout_polynomial_mse.csv` and `output/tables/polynomial_cross_validation.csv`.

### 11. Species and sex effects

**Purpose:** introduce the two-way ANOVA.

**Content:** species and sex both affect body mass, and the interaction is statistically significant.

**Visual:** grouped means with uncertainty intervals or aligned boxplots. Report the interaction p-value next to the plot.

**Source:** `output/tables/two_way_anova.txt` and `output/figures/16_body_mass_by_sex_and_species.png`.

### 12. Interaction interpretation

**Purpose:** explain what the significant interaction means in practical terms.

**Content:** the male-female difference in body mass is not identical across species.

**Visual:** one interaction plot with direct labels at the line ends. Move the second orientation of the interaction plot to the appendix.

**Source:** `output/figures/14_anova_interaction_plots.png` and `output/tables/tukey_hsd.csv`.

### 13. Logistic classification model

**Purpose:** introduce the Adelie-Chinstrap model and its predictors.

**Content:** bill length and flipper length define an interpretable two-variable classifier.

**Visual:** a two-dimensional scatter plot with the decision boundary. Shade the two predicted regions lightly and keep the observed points visible.

**Source:** `output/figures/19_logistic_classification_boundary.png`.

### 14. Classification performance

**Purpose:** report performance without overstating it.

**Content:** accuracy 96.1%, sensitivity 94.0%, specificity 97.1% and AUC 0.993.

**Visual:** confusion matrix on the left and ROC curve on the right. Add a short note that the evaluation is in-sample.

**Source:** `output/tables/logistic_confusion_matrix.csv`, `output/tables/logistic_performance_metrics.csv` and `output/figures/22_logistic_roc_curve.png`.

### 15. Interpretation and limitations

**Purpose:** separate statistical findings from what the data cannot establish.

**Content:** observational design, complete-case filtering, model dependence and in-sample classifier evaluation.

**Visual:** four short statements with one concrete implication each. Avoid a generic “limitations” list without explaining why each point matters.

### 16. Conclusions

**Purpose:** close with the results that answer the original questions.

**Content:** flipper length is the strongest continuous predictor; species and sex explain additional structure; a simple classifier separates Adelie and Chinstrap well within this sample.

**Visual:** three concise findings supported by the relevant values. Do not introduce new analyses on the final slide.

## Appendix

The appendix can contain the complete regression summary, additional pair plots, full influence diagnostics, alternative interval plots, ANOVA assumption checks, Tukey comparisons, Hosmer-Lemeshow results, odds ratios and the probability surface.

## Production steps

1. Run `Rscript scripts/run_all.R` from the repository root.
2. Check the tables used for each slide before importing values into PowerPoint.
3. Rebuild the selected plots with presentation-sized labels and the project palette.
4. Keep charts editable where practical. Do not paste screenshots of R code or console output.
5. Add the data citation to the speaker notes of relevant slides.
6. Export the complete deck to PDF and inspect every slide at presentation size.
7. Check that conclusions, values and sample sizes agree with the current script outputs.

## Current deck

`Penguin_Morphometrics_Current_Deck.pptx` is a four-slide design preview. It should be replaced by the complete deck once the sequence above has been approved and implemented.
