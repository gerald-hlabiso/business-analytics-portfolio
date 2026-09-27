# ============================================================
# 23_interpret_bayesian_model.R
# Interpret the BayesFlight V2 Bayesian model
# ============================================================


# ------------------------------------------------------------
# 1. Load packages and configure R
# ------------------------------------------------------------

library(tidyverse)
library(rstanarm)
library(here)
library(scales)

options(error = NULL)

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

dir.create(
  here("outputs", "summaries"),
  recursive = TRUE,
  showWarnings = FALSE
)


# ------------------------------------------------------------
# 3. Define required file paths
# ------------------------------------------------------------

model_path <- here(
  "models",
  "bayesflight_combined_bayesian_model_v2.rds"
)

prediction_path <- here(
  "data",
  "processed",
  "bayesflight_v2_validation_predictions.rds"
)


# ------------------------------------------------------------
# 4. Check required files
# ------------------------------------------------------------

if (!file.exists(model_path)) {
  stop(
    paste(
      "Model file not found:",
      model_path
    )
  )
}

if (!file.exists(prediction_path)) {
  stop(
    paste(
      "Prediction file not found:",
      prediction_path,
      "\nRun Script 22 first."
    )
  )
}


# ------------------------------------------------------------
# 5. Load model and validation predictions
# ------------------------------------------------------------

bayesflight_model_v2 <- readRDS(
  model_path
)

validation_predictions <- readRDS(
  prediction_path
)

cat("\n====================================================\n")
cat("BAYESFLIGHT V2 MODEL INTERPRETATION\n")
cat("====================================================\n")

cat("\nModel loaded successfully.\n")

cat(
  "Prediction rows:",
  nrow(validation_predictions),
  "\n"
)


# ------------------------------------------------------------
# 6. Check prediction columns
# ------------------------------------------------------------

required_columns <- c(
  "data_split",
  "total_flights",
  "delayed_flights",
  "predicted_probability"
)

missing_columns <- setdiff(
  required_columns,
  names(validation_predictions)
)

if (length(missing_columns) > 0) {
  stop(
    paste(
      "Missing required columns:",
      paste(
        missing_columns,
        collapse = ", "
      )
    )
  )
}


# ------------------------------------------------------------
# 7. Prepare validation predictions
# ------------------------------------------------------------

validation_predictions <- validation_predictions |>
  mutate(
    data_split = as.character(data_split),
    
    total_flights = as.numeric(
      total_flights
    ),
    
    delayed_flights = as.numeric(
      delayed_flights
    ),
    
    predicted_probability = as.numeric(
      predicted_probability
    ),
    
    on_time_flights =
      total_flights - delayed_flights,
    
    observed_delay_rate = if_else(
      total_flights > 0,
      delayed_flights / total_flights,
      NA_real_
    )
  ) |>
  filter(
    !is.na(data_split),
    !is.na(total_flights),
    !is.na(delayed_flights),
    !is.na(predicted_probability),
    total_flights > 0,
    delayed_flights >= 0,
    delayed_flights <= total_flights
  )


# ------------------------------------------------------------
# 8. Extract posterior coefficient draws
# ------------------------------------------------------------

posterior_matrix <- as.matrix(
  bayesflight_model_v2
)

coefficient_names <- names(
  coef(bayesflight_model_v2)
)

missing_coefficient_names <- setdiff(
  coefficient_names,
  colnames(posterior_matrix)
)

if (length(missing_coefficient_names) > 0) {
  stop(
    paste(
      "Posterior draws are missing these coefficients:",
      paste(
        missing_coefficient_names,
        collapse = ", "
      )
    )
  )
}

coefficient_draws <- posterior_matrix[
  ,
  coefficient_names,
  drop = FALSE
]


# ------------------------------------------------------------
# 9. Summarize each model coefficient
# ------------------------------------------------------------

coefficient_summary_list <- lapply(
  coefficient_names,
  function(current_parameter) {
    
    log_odds_draws <- coefficient_draws[
      ,
      current_parameter
    ]
    
    odds_ratio_draws <- exp(
      log_odds_draws
    )
    
    tibble(
      parameter = current_parameter,
      
      log_odds_mean = mean(
        log_odds_draws
      ),
      
      log_odds_median = median(
        log_odds_draws
      ),
      
      log_odds_sd = sd(
        log_odds_draws
      ),
      
      log_odds_lower_95 = unname(
        quantile(
          log_odds_draws,
          0.025
        )
      ),
      
      log_odds_upper_95 = unname(
        quantile(
          log_odds_draws,
          0.975
        )
      ),
      
      odds_ratio_median = median(
        odds_ratio_draws
      ),
      
      odds_ratio_lower_95 = unname(
        quantile(
          odds_ratio_draws,
          0.025
        )
      ),
      
      odds_ratio_upper_95 = unname(
        quantile(
          odds_ratio_draws,
          0.975
        )
      ),
      
      probability_positive = mean(
        log_odds_draws > 0
      ),
      
      probability_negative = mean(
        log_odds_draws < 0
      )
    )
  }
)

coefficient_summary <- bind_rows(
  coefficient_summary_list
)


# ------------------------------------------------------------
# 10. Add coefficient interpretations
# ------------------------------------------------------------

coefficient_summary <- coefficient_summary |>
  mutate(
    parameter_label = parameter |>
      str_replace_all(
        "_",
        " "
      ) |>
      str_replace_all(
        "([a-z])([A-Z])",
        "\\1 \\2"
      ) |>
      str_squish() |>
      str_to_sentence(),
    
    evidence_probability = pmax(
      probability_positive,
      probability_negative
    ),
    
    direction = case_when(
      parameter == "(Intercept)" ~
        "Baseline",
      
      odds_ratio_lower_95 > 1 ~
        "Increases delay risk",
      
      odds_ratio_upper_95 < 1 ~
        "Reduces delay risk",
      
      TRUE ~
        "Uncertain effect"
    ),
    
    evidence_strength = case_when(
      evidence_probability >= 0.99 ~
        "Very strong",
      
      evidence_probability >= 0.95 ~
        "Strong",
      
      evidence_probability >= 0.90 ~
        "Moderate",
      
      TRUE ~
        "Limited"
    ),
    
    percent_change_in_odds =
      (
        odds_ratio_median - 1
      ) * 100
  )


# ------------------------------------------------------------
# 11. Calculate baseline probability
# ------------------------------------------------------------

if ("(Intercept)" %in% coefficient_names) {
  
  intercept_draws <- coefficient_draws[
    ,
    "(Intercept)"
  ]
  
  baseline_probability_draws <- plogis(
    intercept_draws
  )
  
  baseline_summary <- tibble(
    measure =
      "Reference-category baseline delay probability",
    
    posterior_mean = mean(
      baseline_probability_draws
    ),
    
    posterior_median = median(
      baseline_probability_draws
    ),
    
    lower_95 = unname(
      quantile(
        baseline_probability_draws,
        0.025
      )
    ),
    
    upper_95 = unname(
      quantile(
        baseline_probability_draws,
        0.975
      )
    )
  )
  
} else {
  
  baseline_summary <- tibble(
    measure =
      "Reference-category baseline delay probability",
    
    posterior_mean = NA_real_,
    posterior_median = NA_real_,
    lower_95 = NA_real_,
    upper_95 = NA_real_
  )
}

cat("\n====================================================\n")
cat("BASELINE DELAY PROBABILITY\n")
cat("====================================================\n")

print(
  baseline_summary,
  n = Inf,
  width = Inf
)


# ------------------------------------------------------------
# 12. Identify effects that increase delay risk
# ------------------------------------------------------------

risk_increasing_effects <- coefficient_summary |>
  filter(
    parameter != "(Intercept)",
    odds_ratio_lower_95 > 1
  ) |>
  arrange(
    desc(odds_ratio_median)
  )

cat("\n====================================================\n")
cat("FACTORS THAT INCREASE DELAY RISK\n")
cat("====================================================\n")

if (nrow(risk_increasing_effects) > 0) {
  
  print(
    risk_increasing_effects |>
      select(
        parameter,
        odds_ratio_median,
        odds_ratio_lower_95,
        odds_ratio_upper_95,
        percent_change_in_odds,
        evidence_strength
      ),
    n = Inf,
    width = Inf
  )
  
} else {
  
  cat(
    "No clearly positive effects were identified.\n"
  )
}


# ------------------------------------------------------------
# 13. Identify effects that reduce delay risk
# ------------------------------------------------------------

risk_reducing_effects <- coefficient_summary |>
  filter(
    parameter != "(Intercept)",
    odds_ratio_upper_95 < 1
  ) |>
  arrange(
    odds_ratio_median
  )

cat("\n====================================================\n")
cat("FACTORS THAT REDUCE DELAY RISK\n")
cat("====================================================\n")

if (nrow(risk_reducing_effects) > 0) {
  
  print(
    risk_reducing_effects |>
      select(
        parameter,
        odds_ratio_median,
        odds_ratio_lower_95,
        odds_ratio_upper_95,
        percent_change_in_odds,
        evidence_strength
      ),
    n = Inf,
    width = Inf
  )
  
} else {
  
  cat(
    "No clearly negative effects were identified.\n"
  )
}


# ------------------------------------------------------------
# 14. Create coefficient forest plot
# ------------------------------------------------------------

coefficient_plot_data <- coefficient_summary |>
  filter(
    parameter != "(Intercept)"
  ) |>
  mutate(
    parameter_label = fct_reorder(
      parameter_label,
      odds_ratio_median
    )
  )

coefficient_forest_plot <- ggplot(
  coefficient_plot_data,
  aes(
    x = odds_ratio_median,
    y = parameter_label,
    color = direction
  )
) +
  geom_vline(
    xintercept = 1,
    linetype = "dashed",
    color = "gray40",
    linewidth = 0.8
  ) +
  geom_errorbar(
    aes(
      xmin = odds_ratio_lower_95,
      xmax = odds_ratio_upper_95
    ),
    orientation = "y",
    width = 0.2,
    linewidth = 0.8
  ) +
  geom_point(
    size = 3
  ) +
  scale_x_log10(
    labels = label_number(
      accuracy = 0.01
    )
  ) +
  scale_color_manual(
    values = c(
      "Increases delay risk" = "#D64545",
      "Reduces delay risk" = "#2878B5",
      "Uncertain effect" = "#808080"
    )
  ) +
  labs(
    title =
      "Bayesian Effects on Arrival-Delay Risk",
    
    subtitle =
      "Posterior median odds ratios with 95% credible intervals",
    
    x =
      "Odds ratio on logarithmic scale",
    
    y = NULL,
    
    color = NULL,
    
    caption = paste(
      "Odds ratios above 1 indicate higher delay risk;",
      "values below 1 indicate lower delay risk."
    )
  ) +
  theme_minimal(
    base_size = 12
  ) +
  theme(
    plot.title = element_text(
      face = "bold",
      color = "#132238"
    ),
    
    legend.position = "bottom",
    
    panel.grid.minor =
      element_blank()
  )

print(
  coefficient_forest_plot
)


# ------------------------------------------------------------
# 15. Function to summarize operational risk
# ------------------------------------------------------------

create_risk_summary <- function(
    data,
    grouping_variable
) {
  
  prepared_data <- data |>
    filter(
      !is.na(
        .data[[grouping_variable]]
      )
    ) |>
    mutate(
      risk_category = as.character(
        .data[[grouping_variable]]
      )
    )
  
  grouped_data <- prepared_data |>
    group_by(
      data_split,
      risk_category
    ) |>
    summarise(
      predicted_delay_rate = weighted.mean(
        predicted_probability,
        w = total_flights,
        na.rm = TRUE
      ),
      
      group_total_flights = sum(
        total_flights,
        na.rm = TRUE
      ),
      
      group_delayed_flights = sum(
        delayed_flights,
        na.rm = TRUE
      ),
      
      .groups = "drop"
    )
  
  grouped_data |>
    mutate(
      observed_delay_rate =
        group_delayed_flights /
        group_total_flights,
      
      calibration_gap =
        predicted_delay_rate -
        observed_delay_rate,
      
      risk_dimension =
        grouping_variable
    ) |>
    transmute(
      risk_dimension,
      data_split,
      risk_category,
      
      total_flights =
        group_total_flights,
      
      delayed_flights =
        group_delayed_flights,
      
      observed_delay_rate,
      predicted_delay_rate,
      calibration_gap
    )
}


# ------------------------------------------------------------
# 16. Find available operational dimensions
# ------------------------------------------------------------

candidate_risk_dimensions <- c(
  "weather_severity",
  "weather_severity_level",
  "operational_congestion",
  "congestion_level",
  "departure_period",
  "distance_band",
  "season",
  "month",
  "origin",
  "destination"
)

available_risk_dimensions <- intersect(
  candidate_risk_dimensions,
  names(validation_predictions)
)

cat("\nAvailable risk dimensions:\n")

if (length(available_risk_dimensions) == 0) {
  
  cat(
    "No predefined risk dimensions were found.\n"
  )
  
} else {
  
  cat(
    paste(
      available_risk_dimensions,
      collapse = ", "
    ),
    "\n"
  )
}


# ------------------------------------------------------------
# 17. Generate operational risk profiles
# ------------------------------------------------------------

if (length(available_risk_dimensions) > 0) {
  
  risk_summary_list <- lapply(
    available_risk_dimensions,
    function(current_dimension) {
      
      create_risk_summary(
        data = validation_predictions,
        grouping_variable =
          current_dimension
      )
    }
  )
  
  operational_risk_summary <- bind_rows(
    risk_summary_list
  )
  
} else {
  
  operational_risk_summary <- tibble(
    risk_dimension = character(),
    data_split = character(),
    risk_category = character(),
    total_flights = numeric(),
    delayed_flights = numeric(),
    observed_delay_rate = numeric(),
    predicted_delay_rate = numeric(),
    calibration_gap = numeric()
  )
}

cat("\n====================================================\n")
cat("OPERATIONAL RISK PROFILES\n")
cat("====================================================\n")

print(
  operational_risk_summary,
  n = Inf,
  width = Inf
)


# ------------------------------------------------------------
# 18. Select dimensions for the risk chart
# ------------------------------------------------------------

preferred_chart_dimensions <- c(
  "weather_severity",
  "weather_severity_level",
  "operational_congestion",
  "congestion_level",
  "departure_period",
  "distance_band",
  "season"
)

chart_dimensions <- intersect(
  preferred_chart_dimensions,
  available_risk_dimensions
)

chart_dimensions <- head(
  chart_dimensions,
  4
)


# ------------------------------------------------------------
# 19. Create operational risk chart
# ------------------------------------------------------------

operational_risk_chart <- NULL

if (
  nrow(operational_risk_summary) > 0 &&
  length(chart_dimensions) > 0
) {
  
  operational_chart_data <- operational_risk_summary |>
    filter(
      risk_dimension %in%
        chart_dimensions
    )
  
  operational_risk_chart <- ggplot(
    operational_chart_data,
    aes(
      x = risk_category,
      y = predicted_delay_rate,
      fill = data_split
    )
  ) +
    geom_col(
      position = position_dodge(
        width = 0.75
      ),
      width = 0.68
    ) +
    geom_text(
      aes(
        label = percent(
          predicted_delay_rate,
          accuracy = 0.1
        )
      ),
      position = position_dodge(
        width = 0.75
      ),
      vjust = -0.35,
      size = 3.2
    ) +
    facet_wrap(
      ~ risk_dimension,
      scales = "free_x"
    ) +
    scale_fill_manual(
      values = c(
        "Validation" = "#2878B5",
        "Testing" = "#D64545"
      )
    ) +
    scale_y_continuous(
      labels = percent_format(
        accuracy = 1
      ),
      expand = expansion(
        mult = c(0, 0.14)
      )
    ) +
    labs(
      title =
        "Predicted Delay Risk by Operational Condition",
      
      subtitle =
        "BayesFlight V2 validation and testing results",
      
      x = NULL,
      
      y =
        "Predicted arrival-delay probability",
      
      fill =
        "Data split"
    ) +
    theme_minimal(
      base_size = 11
    ) +
    theme(
      plot.title = element_text(
        face = "bold",
        color = "#132238"
      ),
      
      axis.text.x = element_text(
        angle = 35,
        hjust = 1
      ),
      
      legend.position = "bottom",
      
      panel.grid.minor =
        element_blank()
    )
  
  print(
    operational_risk_chart
  )
}


# ------------------------------------------------------------
# 20. Create written interpretation
# ------------------------------------------------------------

if (is.na(baseline_summary$posterior_median)) {
  
  baseline_text <- paste(
    "The model did not contain",
    "a separate intercept."
  )
  
} else {
  
  baseline_text <- paste0(
    "The reference-category baseline delay probability was ",
    percent(
      baseline_summary$posterior_median,
      accuracy = 0.1
    ),
    "."
  )
}

if (nrow(risk_increasing_effects) > 0) {
  
  strongest_increase <- risk_increasing_effects |>
    slice(1)
  
  strongest_increase_text <- paste0(
    strongest_increase$parameter,
    " had the strongest clearly positive effect, ",
    "with a median odds ratio of ",
    round(
      strongest_increase$odds_ratio_median,
      2
    ),
    " and a 95% credible interval from ",
    round(
      strongest_increase$odds_ratio_lower_95,
      2
    ),
    " to ",
    round(
      strongest_increase$odds_ratio_upper_95,
      2
    ),
    "."
  )
  
} else {
  
  strongest_increase_text <-
    "No clearly positive effects were identified."
}

if (nrow(risk_reducing_effects) > 0) {
  
  strongest_reduction <- risk_reducing_effects |>
    slice(1)
  
  strongest_reduction_text <- paste0(
    strongest_reduction$parameter,
    " had the strongest clearly negative effect, ",
    "with a median odds ratio of ",
    round(
      strongest_reduction$odds_ratio_median,
      2
    ),
    " and a 95% credible interval from ",
    round(
      strongest_reduction$odds_ratio_lower_95,
      2
    ),
    " to ",
    round(
      strongest_reduction$odds_ratio_upper_95,
      2
    ),
    "."
  )
  
} else {
  
  strongest_reduction_text <-
    "No clearly negative effects were identified."
}

interpretation_lines <- c(
  "BAYESFLIGHT V2 MODEL INTERPRETATION",
  "===================================",
  "",
  baseline_text,
  "",
  strongest_increase_text,
  "",
  strongest_reduction_text,
  "",
  paste0(
    nrow(risk_increasing_effects),
    " predictor levels clearly increased delay risk, while ",
    nrow(risk_reducing_effects),
    " predictor levels clearly reduced delay risk."
  ),
  "",
  paste(
    "An effect was considered clear when its entire",
    "95% Bayesian credible interval for the odds ratio",
    "was above or below 1."
  ),
  "",
  paste(
    "These results represent posterior associations",
    "and should not automatically be interpreted",
    "as causal effects."
  )
)

writeLines(
  interpretation_lines,
  here(
    "outputs",
    "summaries",
    "bayesflight_v2_model_interpretation.txt"
  )
)


# ------------------------------------------------------------
# 21. Save result tables
# ------------------------------------------------------------

write_csv(
  coefficient_summary,
  here(
    "outputs",
    "tables",
    "bayesflight_v2_coefficient_interpretation.csv"
  )
)

write_csv(
  baseline_summary,
  here(
    "outputs",
    "tables",
    "bayesflight_v2_baseline_probability.csv"
  )
)

write_csv(
  risk_increasing_effects,
  here(
    "outputs",
    "tables",
    "bayesflight_v2_risk_increasing_effects.csv"
  )
)

write_csv(
  risk_reducing_effects,
  here(
    "outputs",
    "tables",
    "bayesflight_v2_risk_reducing_effects.csv"
  )
)

write_csv(
  operational_risk_summary,
  here(
    "outputs",
    "tables",
    "bayesflight_v2_operational_risk_profiles.csv"
  )
)


# ------------------------------------------------------------
# 22. Save figures
# ------------------------------------------------------------

ggsave(
  filename = here(
    "outputs",
    "figures",
    "bayesflight_v2_odds_ratio_forest_plot.png"
  ),
  plot = coefficient_forest_plot,
  width = 11,
  height = 8,
  dpi = 300
)

if (!is.null(operational_risk_chart)) {
  
  ggsave(
    filename = here(
      "outputs",
      "figures",
      "bayesflight_v2_operational_risk_profiles.png"
    ),
    plot = operational_risk_chart,
    width = 12,
    height = 8,
    dpi = 300
  )
}


# ------------------------------------------------------------
# 23. Final confirmation
# ------------------------------------------------------------

cat("\n====================================================\n")
cat("MODEL INTERPRETATION COMPLETED SUCCESSFULLY!\n")
cat("====================================================\n")

cat("\nSaved tables:\n")
cat("- bayesflight_v2_coefficient_interpretation.csv\n")
cat("- bayesflight_v2_baseline_probability.csv\n")
cat("- bayesflight_v2_risk_increasing_effects.csv\n")
cat("- bayesflight_v2_risk_reducing_effects.csv\n")
cat("- bayesflight_v2_operational_risk_profiles.csv\n")

cat("\nSaved figures:\n")
cat("- bayesflight_v2_odds_ratio_forest_plot.png\n")

if (!is.null(operational_risk_chart)) {
  cat("- bayesflight_v2_operational_risk_profiles.png\n")
}

cat("\nSaved interpretation:\n")
cat("- bayesflight_v2_model_interpretation.txt\n")

cat("\nStep 23 is complete.\n")
cat("====================================================\n")