# ============================================================
# 22_validate_bayesian_model.R
# Validate the improved BayesFlight V2 model
# ============================================================

# ------------------------------------------------------------
# 1. Load packages
# ------------------------------------------------------------

library(tidyverse)
library(rstanarm)
library(here)

options(mc.cores = parallel::detectCores())

set.seed(2025)


# ------------------------------------------------------------
# 2. Create output folders
# ------------------------------------------------------------

dir.create(
  here("outputs", "tables"),
  recursive = TRUE,
  showWarnings = FALSE
)

dir.create(
  here("outputs", "figures"),
  recursive = TRUE,
  showWarnings = FALSE
)


# ------------------------------------------------------------
# 3. Define file paths
# ------------------------------------------------------------

model_path <- here(
  "models",
  "bayesflight_combined_bayesian_model_v2.rds"
)

data_path <- here(
  "data",
  "processed",
  "bayesflight_aggregated_model_data.rds"
)


# ------------------------------------------------------------
# 4. Check that the required files exist
# ------------------------------------------------------------

if (!file.exists(model_path)) {
  stop(
    paste(
      "The V2 model file was not found:",
      model_path
    )
  )
}

if (!file.exists(data_path)) {
  stop(
    paste(
      "The aggregated modeling dataset was not found:",
      data_path
    )
  )
}


# ------------------------------------------------------------
# 5. Load the model and modeling data
# ------------------------------------------------------------

bayesflight_model_v2 <- readRDS(model_path)

aggregated_model_data <- readRDS(data_path)

cat("\n====================================================\n")
cat("BAYESFLIGHT V2 CHRONOLOGICAL VALIDATION\n")
cat("====================================================\n")

cat("\nModel loaded from:\n")
cat(model_path, "\n")

cat("\nData loaded from:\n")
cat(data_path, "\n")

cat("\nNumber of rows:", nrow(aggregated_model_data), "\n")


# ------------------------------------------------------------
# 6. Check required columns
# ------------------------------------------------------------

required_columns <- c(
  "data_split",
  "total_flights",
  "delayed_flights"
)

missing_columns <- setdiff(
  required_columns,
  names(aggregated_model_data)
)

if (length(missing_columns) > 0) {
  stop(
    paste(
      "These required columns are missing:",
      paste(missing_columns, collapse = ", ")
    )
  )
}


# ------------------------------------------------------------
# 7. Prepare validation and testing data
# ------------------------------------------------------------

validation_data <- aggregated_model_data |>
  filter(data_split == "Validation")

testing_data <- aggregated_model_data |>
  filter(data_split == "Testing")

if (nrow(validation_data) == 0) {
  stop("No Validation rows were found.")
}

if (nrow(testing_data) == 0) {
  stop("No Testing rows were found.")
}

evaluation_data <- bind_rows(
  validation_data,
  testing_data
) |>
  mutate(
    total_flights = as.numeric(total_flights),
    delayed_flights = as.numeric(delayed_flights),
    on_time_flights = total_flights - delayed_flights,
    observed_delay_rate = if_else(
      total_flights > 0,
      delayed_flights / total_flights,
      NA_real_
    )
  ) |>
  filter(
    !is.na(total_flights),
    !is.na(delayed_flights),
    total_flights > 0,
    delayed_flights >= 0,
    delayed_flights <= total_flights
  )


# ------------------------------------------------------------
# 8. Generate posterior predictions
# ------------------------------------------------------------

cat("\nGenerating posterior predictions...\n")

posterior_predictions <- posterior_epred(
  bayesflight_model_v2,
  newdata = evaluation_data
)

evaluation_data$predicted_probability <- apply(
  posterior_predictions,
  2,
  median
)

evaluation_data$predicted_rate_lower_95 <- apply(
  posterior_predictions,
  2,
  quantile,
  probs = 0.025
)

evaluation_data$predicted_rate_upper_95 <- apply(
  posterior_predictions,
  2,
  quantile,
  probs = 0.975
)

cat("Posterior predictions completed successfully.\n")


# ------------------------------------------------------------
# 9. Weighted ROC-AUC function
# ------------------------------------------------------------

weighted_roc_auc <- function(
    probability,
    delayed_flights,
    on_time_flights
) {
  
  roc_data <- tibble(
    probability = probability,
    positive_weight = delayed_flights,
    negative_weight = on_time_flights
  ) |>
    filter(
      !is.na(probability),
      !is.na(positive_weight),
      !is.na(negative_weight)
    ) |>
    arrange(probability)
  
  total_positive <- sum(roc_data$positive_weight)
  
  total_negative <- sum(roc_data$negative_weight)
  
  if (total_positive == 0 || total_negative == 0) {
    return(NA_real_)
  }
  
  cumulative_negative_before <- c(
    0,
    head(cumsum(roc_data$negative_weight), -1)
  )
  
  concordant_pairs <- sum(
    roc_data$positive_weight *
      (
        cumulative_negative_before +
          0.5 * roc_data$negative_weight
      )
  )
  
  concordant_pairs / (total_positive * total_negative)
}


# ------------------------------------------------------------
# 10. Weighted PR-AUC function
# ------------------------------------------------------------

weighted_pr_auc <- function(
    probability,
    delayed_flights,
    on_time_flights
) {
  
  pr_data <- tibble(
    probability = probability,
    positive_weight = delayed_flights,
    negative_weight = on_time_flights
  ) |>
    filter(
      !is.na(probability),
      !is.na(positive_weight),
      !is.na(negative_weight)
    ) |>
    arrange(desc(probability))
  
  total_positive <- sum(pr_data$positive_weight)
  
  if (total_positive == 0) {
    return(NA_real_)
  }
  
  pr_data <- pr_data |>
    mutate(
      true_positive = cumsum(positive_weight),
      false_positive = cumsum(negative_weight),
      recall = true_positive / total_positive,
      precision = true_positive /
        (true_positive + false_positive)
    )
  
  recall_values <- c(0, pr_data$recall)
  
  precision_values <- c(1, pr_data$precision)
  
  sum(
    diff(recall_values) *
      (
        head(precision_values, -1) +
          tail(precision_values, -1)
      ) / 2
  )
}


# ------------------------------------------------------------
# 11. Calculate chronological performance metrics
# ------------------------------------------------------------

performance_list <- lapply(
  unique(evaluation_data$data_split),
  function(current_split) {
    
    split_data <- evaluation_data |>
      filter(data_split == current_split)
    
    observed_rate <- sum(
      split_data$delayed_flights,
      na.rm = TRUE
    ) / sum(
      split_data$total_flights,
      na.rm = TRUE
    )
    
    predicted_rate <- weighted.mean(
      split_data$predicted_probability,
      w = split_data$total_flights,
      na.rm = TRUE
    )
    
    brier_score <- weighted.mean(
      (
        split_data$observed_delay_rate -
          split_data$predicted_probability
      )^2,
      w = split_data$total_flights,
      na.rm = TRUE
    )
    
    clipped_probability <- pmin(
      pmax(
        split_data$predicted_probability,
        0.000001
      ),
      0.999999
    )
    
    log_loss_values <- -(
      split_data$observed_delay_rate *
        log(clipped_probability) +
        (
          1 - split_data$observed_delay_rate
        ) *
        log(1 - clipped_probability)
    )
    
    log_loss <- weighted.mean(
      log_loss_values,
      w = split_data$total_flights,
      na.rm = TRUE
    )
    
    mean_absolute_error <- weighted.mean(
      abs(
        split_data$observed_delay_rate -
          split_data$predicted_probability
      ),
      w = split_data$total_flights,
      na.rm = TRUE
    )
    
    predicted_lower <- weighted.mean(
      split_data$predicted_rate_lower_95,
      w = split_data$total_flights,
      na.rm = TRUE
    )
    
    predicted_median <- weighted.mean(
      split_data$predicted_probability,
      w = split_data$total_flights,
      na.rm = TRUE
    )
    
    predicted_upper <- weighted.mean(
      split_data$predicted_rate_upper_95,
      w = split_data$total_flights,
      na.rm = TRUE
    )
    
    roc_auc <- weighted_roc_auc(
      probability = split_data$predicted_probability,
      delayed_flights = split_data$delayed_flights,
      on_time_flights = split_data$on_time_flights
    )
    
    pr_auc <- weighted_pr_auc(
      probability = split_data$predicted_probability,
      delayed_flights = split_data$delayed_flights,
      on_time_flights = split_data$on_time_flights
    )
    
    tibble(
      data_split = current_split,
      total_flights = sum(
        split_data$total_flights,
        na.rm = TRUE
      ),
      observed_delay_rate = observed_rate,
      predicted_delay_rate = predicted_rate,
      calibration_gap = predicted_rate - observed_rate,
      weighted_brier_score = brier_score,
      weighted_log_loss = log_loss,
      weighted_mae = mean_absolute_error,
      predicted_rate_lower_95 = predicted_lower,
      predicted_rate_median = predicted_median,
      predicted_rate_upper_95 = predicted_upper,
      weighted_roc_auc = roc_auc,
      weighted_pr_auc = pr_auc
    )
  }
)

chronological_performance <- bind_rows(
  performance_list
) |>
  mutate(
    data_split = factor(
      data_split,
      levels = c("Validation", "Testing")
    )
  ) |>
  arrange(data_split) |>
  mutate(
    data_split = as.character(data_split)
  )

cat("\n====================================================\n")
cat("CHRONOLOGICAL MODEL PERFORMANCE\n")
cat("====================================================\n")

print(
  chronological_performance,
  n = Inf,
  width = Inf
)


# ------------------------------------------------------------
# 12. Create the corrected calibration table
# ------------------------------------------------------------

calibration_table <- evaluation_data |>
  mutate(
    probability_bin = cut(
      predicted_probability,
      breaks = seq(0, 1, by = 0.1),
      include.lowest = TRUE,
      right = TRUE
    )
  ) |>
  group_by(
    data_split,
    probability_bin
  ) |>
  summarise(
    observed_delay_rate = sum(
      delayed_flights,
      na.rm = TRUE
    ) / sum(
      total_flights,
      na.rm = TRUE
    ),
    
    predicted_delay_rate = weighted.mean(
      predicted_probability,
      w = total_flights,
      na.rm = TRUE
    ),
    
    total_flights = sum(
      total_flights,
      na.rm = TRUE
    ),
    
    .groups = "drop"
  ) |>
  filter(
    is.finite(observed_delay_rate),
    is.finite(predicted_delay_rate),
    total_flights > 0
  )

cat("\n====================================================\n")
cat("CALIBRATION TABLE\n")
cat("====================================================\n")

print(
  calibration_table,
  n = Inf,
  width = Inf
)


# ------------------------------------------------------------
# 13. Create calibration chart
# ------------------------------------------------------------

calibration_chart <- ggplot(
  calibration_table,
  aes(
    x = predicted_delay_rate,
    y = observed_delay_rate,
    color = data_split,
    size = total_flights
  )
) +
  geom_abline(
    intercept = 0,
    slope = 1,
    linetype = "dashed",
    color = "gray45",
    linewidth = 0.8
  ) +
  geom_point(
    alpha = 0.85
  ) +
  geom_line(
    aes(group = data_split),
    linewidth = 0.8,
    alpha = 0.75
  ) +
  scale_color_manual(
    values = c(
      "Validation" = "#2E86DE",
      "Testing" = "#E74C3C"
    )
  ) +
  scale_x_continuous(
    labels = scales::percent_format(accuracy = 1)
  ) +
  scale_y_continuous(
    labels = scales::percent_format(accuracy = 1)
  ) +
  labs(
    title = "BayesFlight V2 Calibration",
    subtitle = paste(
      "Chronological validation and testing;",
      "dashed line represents perfect calibration"
    ),
    x = "Predicted probability of arrival delay",
    y = "Observed arrival-delay rate",
    color = "Data split",
    size = "Flights"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(
      face = "bold",
      color = "#132238"
    ),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )

print(calibration_chart)


# ------------------------------------------------------------
# 14. Create predicted-versus-observed chart
# ------------------------------------------------------------

performance_chart_data <- chronological_performance |>
  select(
    data_split,
    observed_delay_rate,
    predicted_delay_rate
  ) |>
  pivot_longer(
    cols = c(
      observed_delay_rate,
      predicted_delay_rate
    ),
    names_to = "rate_type",
    values_to = "delay_rate"
  ) |>
  mutate(
    rate_type = recode(
      rate_type,
      observed_delay_rate = "Observed",
      predicted_delay_rate = "Predicted"
    )
  )

performance_chart <- ggplot(
  performance_chart_data,
  aes(
    x = data_split,
    y = delay_rate,
    fill = rate_type
  )
) +
  geom_col(
    position = position_dodge(width = 0.75),
    width = 0.65
  ) +
  geom_text(
    aes(
      label = scales::percent(
        delay_rate,
        accuracy = 0.1
      )
    ),
    position = position_dodge(width = 0.75),
    vjust = -0.4,
    size = 4
  ) +
  scale_fill_manual(
    values = c(
      "Observed" = "#132238",
      "Predicted" = "#2E86DE"
    )
  ) +
  scale_y_continuous(
    labels = scales::percent_format(accuracy = 1),
    expand = expansion(mult = c(0, 0.12))
  ) +
  labs(
    title = "Observed and Predicted Delay Rates",
    subtitle = "BayesFlight V2 chronological evaluation",
    x = NULL,
    y = "Arrival-delay rate",
    fill = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(
      face = "bold",
      color = "#132238"
    ),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )

print(performance_chart)


# ------------------------------------------------------------
# 15. Save tables
# ------------------------------------------------------------

write_csv(
  chronological_performance,
  here(
    "outputs",
    "tables",
    "bayesflight_v2_chronological_performance.csv"
  )
)

write_csv(
  calibration_table,
  here(
    "outputs",
    "tables",
    "bayesflight_v2_calibration_table.csv"
  )
)


# ------------------------------------------------------------
# 16. Save figures
# ------------------------------------------------------------

ggsave(
  filename = here(
    "outputs",
    "figures",
    "bayesflight_v2_calibration.png"
  ),
  plot = calibration_chart,
  width = 10,
  height = 7,
  dpi = 300
)

ggsave(
  filename = here(
    "outputs",
    "figures",
    "bayesflight_v2_observed_vs_predicted.png"
  ),
  plot = performance_chart,
  width = 9,
  height = 6,
  dpi = 300
)


# ------------------------------------------------------------
# 17. Save prediction data
# ------------------------------------------------------------

saveRDS(
  evaluation_data,
  here(
    "data",
    "processed",
    "bayesflight_v2_validation_predictions.rds"
  ),
  compress = "gzip"
)


# ------------------------------------------------------------
# 18. Final result
# ------------------------------------------------------------

cat("\n====================================================\n")
cat("VALIDATION COMPLETED SUCCESSFULLY!\n")
cat("====================================================\n")

cat("\nSaved tables:\n")
cat(
  "- outputs/tables/",
  "bayesflight_v2_chronological_performance.csv\n",
  sep = ""
)

cat(
  "- outputs/tables/",
  "bayesflight_v2_calibration_table.csv\n",
  sep = ""
)

cat("\nSaved figures:\n")
cat(
  "- outputs/figures/",
  "bayesflight_v2_calibration.png\n",
  sep = ""
)

cat(
  "- outputs/figures/",
  "bayesflight_v2_observed_vs_predicted.png\n",
  sep = ""
)

cat("\nSaved validation predictions:\n")
cat(
  "- data/processed/",
  "bayesflight_v2_validation_predictions.rds\n",
  sep = ""
)

cat("\nThe V2 model has completed chronological validation.\n")
cat("====================================================\n")