# ============================================================
# 24_build_delay_risk_scoring_system.R
# Build the BayesFlight delay-risk scoring system
# ============================================================


# ------------------------------------------------------------
# 1. Load packages
# ------------------------------------------------------------

library(tidyverse)
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
# 3. Define prediction file
# ------------------------------------------------------------

prediction_path <- here(
  "data",
  "processed",
  "bayesflight_v2_validation_predictions.rds"
)

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
# 4. Load validation predictions
# ------------------------------------------------------------

risk_data <- readRDS(
  prediction_path
)

required_columns <- c(
  "data_split",
  "total_flights",
  "delayed_flights",
  "predicted_probability"
)

missing_columns <- setdiff(
  required_columns,
  names(risk_data)
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

cat("\n====================================================\n")
cat("BAYESFLIGHT DELAY-RISK SCORING SYSTEM\n")
cat("====================================================\n")

cat(
  "\nRows loaded:",
  nrow(risk_data),
  "\n"
)


# ------------------------------------------------------------
# 5. Prepare data
# ------------------------------------------------------------

risk_data <- risk_data |>
  mutate(
    data_split = as.character(
      data_split
    ),
    
    total_flights = as.numeric(
      total_flights
    ),
    
    delayed_flights = as.numeric(
      delayed_flights
    ),
    
    predicted_probability = as.numeric(
      predicted_probability
    ),
    
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
    delayed_flights <= total_flights,
    predicted_probability >= 0,
    predicted_probability <= 1
  )


# ------------------------------------------------------------
# 6. Define risk thresholds
# ------------------------------------------------------------

low_threshold <- 0.15
moderate_threshold <- 0.25
high_threshold <- 0.40

risk_threshold_table <- tibble(
  risk_level = c(
    "Low",
    "Moderate",
    "High",
    "Severe"
  ),
  
  minimum_probability = c(
    0,
    low_threshold,
    moderate_threshold,
    high_threshold
  ),
  
  maximum_probability = c(
    low_threshold,
    moderate_threshold,
    high_threshold,
    1
  ),
  
  score_range = c(
    "0–14.9",
    "15–24.9",
    "25–39.9",
    "40–100"
  ),
  
  recommended_action = c(
    "Normal monitoring",
    "Monitor operating conditions",
    "Review and prepare mitigation",
    "Immediate operational attention"
  )
)

cat("\n====================================================\n")
cat("RISK THRESHOLDS\n")
cat("====================================================\n")

print(
  risk_threshold_table,
  n = Inf,
  width = Inf
)


# ------------------------------------------------------------
# 7. Assign risk scores and risk levels
# ------------------------------------------------------------

scored_flights <- risk_data |>
  mutate(
    delay_risk_score = round(
      predicted_probability * 100,
      1
    ),
    
    risk_level = case_when(
      predicted_probability <
        low_threshold ~ "Low",
      
      predicted_probability <
        moderate_threshold ~ "Moderate",
      
      predicted_probability <
        high_threshold ~ "High",
      
      TRUE ~ "Severe"
    ),
    
    risk_level = factor(
      risk_level,
      levels = c(
        "Low",
        "Moderate",
        "High",
        "Severe"
      ),
      ordered = TRUE
    ),
    
    recommended_action = case_when(
      risk_level == "Low" ~
        "Normal monitoring",
      
      risk_level == "Moderate" ~
        "Monitor operating conditions",
      
      risk_level == "High" ~
        "Review and prepare mitigation",
      
      risk_level == "Severe" ~
        "Immediate operational attention"
    )
  )


# ------------------------------------------------------------
# 8. Add uncertainty classification
# ------------------------------------------------------------

if (
  all(
    c(
      "predicted_rate_lower_95",
      "predicted_rate_upper_95"
    ) %in% names(scored_flights)
  )
) {
  
  scored_flights <- scored_flights |>
    mutate(
      interval_width =
        predicted_rate_upper_95 -
        predicted_rate_lower_95,
      
      uncertainty_level = case_when(
        interval_width <= 0.05 ~ "Low",
        interval_width <= 0.10 ~ "Moderate",
        TRUE ~ "High"
      )
    )
  
} else {
  
  scored_flights <- scored_flights |>
    mutate(
      interval_width = NA_real_,
      uncertainty_level = "Unavailable"
    )
}


# ------------------------------------------------------------
# 9. Add alert priority
# ------------------------------------------------------------

scored_flights <- scored_flights |>
  mutate(
    alert_priority = case_when(
      risk_level == "Severe" &
        uncertainty_level %in%
        c("Low", "Moderate") ~
        "Priority 1",
      
      risk_level == "Severe" ~
        "Priority 2",
      
      risk_level == "High" ~
        "Priority 2",
      
      risk_level == "Moderate" ~
        "Priority 3",
      
      TRUE ~
        "Routine"
    ),
    
    alert_priority = factor(
      alert_priority,
      levels = c(
        "Routine",
        "Priority 3",
        "Priority 2",
        "Priority 1"
      ),
      ordered = TRUE
    )
  )


# ------------------------------------------------------------
# 10. Create risk-level performance summary
# ------------------------------------------------------------

risk_level_summary <- scored_flights |>
  group_by(
    data_split,
    risk_level
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
    
    number_of_records = n(),
    
    .groups = "drop"
  ) |>
  mutate(
    observed_delay_rate =
      group_delayed_flights /
      group_total_flights,
    
    calibration_gap =
      predicted_delay_rate -
      observed_delay_rate,
    
    share_of_all_flights =
      group_total_flights /
      sum(group_total_flights)
  ) |>
  transmute(
    data_split,
    risk_level,
    
    total_flights =
      group_total_flights,
    
    delayed_flights =
      group_delayed_flights,
    
    number_of_records,
    share_of_all_flights,
    observed_delay_rate,
    predicted_delay_rate,
    calibration_gap
  )

cat("\n====================================================\n")
cat("RISK-LEVEL PERFORMANCE\n")
cat("====================================================\n")

print(
  risk_level_summary,
  n = Inf,
  width = Inf
)


# ------------------------------------------------------------
# 11. Create alert-priority summary
# ------------------------------------------------------------

alert_priority_summary <- scored_flights |>
  group_by(
    data_split,
    alert_priority
  ) |>
  summarise(
    average_risk_score = weighted.mean(
      delay_risk_score,
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
    
    number_of_records = n(),
    
    .groups = "drop"
  ) |>
  mutate(
    observed_delay_rate =
      group_delayed_flights /
      group_total_flights
  ) |>
  transmute(
    data_split,
    alert_priority,
    
    total_flights =
      group_total_flights,
    
    delayed_flights =
      group_delayed_flights,
    
    number_of_records,
    average_risk_score,
    observed_delay_rate
  )

cat("\n====================================================\n")
cat("ALERT-PRIORITY SUMMARY\n")
cat("====================================================\n")

print(
  alert_priority_summary,
  n = Inf,
  width = Inf
)


# ------------------------------------------------------------
# 12. Function for ranked operational summaries
# ------------------------------------------------------------

create_ranked_summary <- function(
    data,
    grouping_columns,
    minimum_flights = 100
) {
  
  data |>
    group_by(
      across(
        all_of(grouping_columns)
      )
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
    ) |>
    filter(
      group_total_flights >=
        minimum_flights
    ) |>
    mutate(
      observed_delay_rate =
        group_delayed_flights /
        group_total_flights,
      
      delay_risk_score = round(
        predicted_delay_rate * 100,
        1
      ),
      
      risk_level = case_when(
        predicted_delay_rate <
          low_threshold ~ "Low",
        
        predicted_delay_rate <
          moderate_threshold ~ "Moderate",
        
        predicted_delay_rate <
          high_threshold ~ "High",
        
        TRUE ~ "Severe"
      ),
      
      calibration_gap =
        predicted_delay_rate -
        observed_delay_rate
    ) |>
    rename(
      total_flights =
        group_total_flights,
      
      delayed_flights =
        group_delayed_flights
    ) |>
    arrange(
      desc(delay_risk_score)
    )
}


# ------------------------------------------------------------
# 13. Create airport risk ranking
# ------------------------------------------------------------

airport_risk_ranking <- tibble()

if ("origin" %in% names(scored_flights)) {
  
  airport_risk_ranking <- create_ranked_summary(
    data = scored_flights,
    grouping_columns = c(
      "data_split",
      "origin"
    ),
    minimum_flights = 500
  ) |>
    group_by(data_split) |>
    mutate(
      airport_risk_rank =
        row_number()
    ) |>
    ungroup()
  
  cat("\n====================================================\n")
  cat("HIGHEST-RISK ORIGIN AIRPORTS\n")
  cat("====================================================\n")
  
  print(
    airport_risk_ranking |>
      group_by(data_split) |>
      slice_head(n = 15) |>
      ungroup(),
    n = Inf,
    width = Inf
  )
}


# ------------------------------------------------------------
# 14. Create route risk ranking
# ------------------------------------------------------------

route_risk_ranking <- tibble()

if (
  all(
    c(
      "origin",
      "destination"
    ) %in% names(scored_flights)
  )
) {
  
  route_risk_ranking <- create_ranked_summary(
    data = scored_flights,
    grouping_columns = c(
      "data_split",
      "origin",
      "destination"
    ),
    minimum_flights = 100
  ) |>
    group_by(data_split) |>
    mutate(
      route_risk_rank =
        row_number()
    ) |>
    ungroup()
  
  cat("\n====================================================\n")
  cat("HIGHEST-RISK ROUTES\n")
  cat("====================================================\n")
  
  print(
    route_risk_ranking |>
      group_by(data_split) |>
      slice_head(n = 15) |>
      ungroup(),
    n = Inf,
    width = Inf
  )
}


# ------------------------------------------------------------
# 15. Create high-priority alert queue
# ------------------------------------------------------------

alert_queue <- scored_flights |>
  filter(
    alert_priority %in%
      c(
        "Priority 1",
        "Priority 2"
      )
  ) |>
  arrange(
    desc(alert_priority),
    desc(delay_risk_score),
    desc(total_flights)
  )

cat("\n====================================================\n")
cat("HIGH-PRIORITY ALERT QUEUE\n")
cat("====================================================\n")

print(
  alert_queue |>
    select(
      any_of(
        c(
          "data_split",
          "origin",
          "destination",
          "weather_severity",
          "operational_congestion",
          "departure_period",
          "distance_band",
          "delay_risk_score",
          "risk_level",
          "uncertainty_level",
          "alert_priority",
          "recommended_action",
          "total_flights"
        )
      )
    ) |>
    slice_head(n = 25),
  n = Inf,
  width = Inf
)


# ------------------------------------------------------------
# 16. Create risk distribution chart
# ------------------------------------------------------------

risk_distribution_chart <- ggplot(
  risk_level_summary,
  aes(
    x = risk_level,
    y = total_flights,
    fill = risk_level
  )
) +
  geom_col(
    width = 0.7
  ) +
  geom_text(
    aes(
      label = comma(
        total_flights
      )
    ),
    vjust = -0.35,
    size = 3.5
  ) +
  facet_wrap(
    ~ data_split,
    scales = "free_y"
  ) +
  scale_fill_manual(
    values = c(
      "Low" = "#2E86DE",
      "Moderate" = "#F1C40F",
      "High" = "#E67E22",
      "Severe" = "#D64545"
    ),
    drop = FALSE
  ) +
  scale_y_continuous(
    labels = label_comma(),
    expand = expansion(
      mult = c(0, 0.12)
    )
  ) +
  labs(
    title =
      "Flight Volume by Bayesian Delay-Risk Level",
    
    subtitle =
      "BayesFlight V2 chronological evaluation",
    
    x =
      "Delay-risk level",
    
    y =
      "Number of flights",
    
    fill = NULL
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
  risk_distribution_chart
)


# ------------------------------------------------------------
# 17. Create observed-versus-predicted risk chart
# ------------------------------------------------------------

risk_calibration_chart <- risk_level_summary |>
  select(
    data_split,
    risk_level,
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
  ) |>
  ggplot(
    aes(
      x = risk_level,
      y = delay_rate,
      fill = rate_type
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
        delay_rate,
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
    ~ data_split
  ) +
  scale_fill_manual(
    values = c(
      "Observed" = "#132238",
      "Predicted" = "#2E86DE"
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
      "Observed and Predicted Delay Rates by Risk Level",
    
    subtitle =
      "Higher risk levels should show progressively higher delay rates",
    
    x =
      "Delay-risk level",
    
    y =
      "Arrival-delay rate",
    
    fill = NULL
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
  risk_calibration_chart
)


# ------------------------------------------------------------
# 18. Save scored dataset
# ------------------------------------------------------------

saveRDS(
  scored_flights,
  here(
    "data",
    "processed",
    "bayesflight_v2_scored_flights.rds"
  ),
  compress = "gzip"
)

write_csv(
  scored_flights,
  here(
    "outputs",
    "tables",
    "bayesflight_v2_scored_flights.csv"
  )
)


# ------------------------------------------------------------
# 19. Save summary tables
# ------------------------------------------------------------

write_csv(
  risk_threshold_table,
  here(
    "outputs",
    "tables",
    "bayesflight_v2_risk_thresholds.csv"
  )
)

write_csv(
  risk_level_summary,
  here(
    "outputs",
    "tables",
    "bayesflight_v2_risk_level_summary.csv"
  )
)

write_csv(
  alert_priority_summary,
  here(
    "outputs",
    "tables",
    "bayesflight_v2_alert_priority_summary.csv"
  )
)

write_csv(
  alert_queue,
  here(
    "outputs",
    "tables",
    "bayesflight_v2_alert_queue.csv"
  )
)

if (nrow(airport_risk_ranking) > 0) {
  write_csv(
    airport_risk_ranking,
    here(
      "outputs",
      "tables",
      "bayesflight_v2_airport_risk_ranking.csv"
    )
  )
}

if (nrow(route_risk_ranking) > 0) {
  write_csv(
    route_risk_ranking,
    here(
      "outputs",
      "tables",
      "bayesflight_v2_route_risk_ranking.csv"
    )
  )
}


# ------------------------------------------------------------
# 20. Save charts
# ------------------------------------------------------------

ggsave(
  filename = here(
    "outputs",
    "figures",
    "bayesflight_v2_risk_distribution.png"
  ),
  plot = risk_distribution_chart,
  width = 10,
  height = 6,
  dpi = 300
)

ggsave(
  filename = here(
    "outputs",
    "figures",
    "bayesflight_v2_risk_level_calibration.png"
  ),
  plot = risk_calibration_chart,
  width = 11,
  height = 7,
  dpi = 300
)


# ------------------------------------------------------------
# 21. Save scoring-system description
# ------------------------------------------------------------

scoring_description <- c(
  "BAYESFLIGHT V2 DELAY-RISK SCORING SYSTEM",
  "========================================",
  "",
  "Risk score:",
  "The Bayesian predicted probability is multiplied by 100.",
  "",
  "Risk levels:",
  "Low: predicted delay probability below 15%.",
  "Moderate: predicted delay probability from 15% to below 25%.",
  "High: predicted delay probability from 25% to below 40%.",
  "Severe: predicted delay probability of 40% or higher.",
  "",
  "Operational actions:",
  "Low: normal monitoring.",
  "Moderate: monitor operating conditions.",
  "High: review conditions and prepare mitigation.",
  "Severe: immediate operational attention.",
  "",
  paste(
    "The risk tiers are decision-support categories",
    "and should be monitored for calibration drift."
  )
)

writeLines(
  scoring_description,
  here(
    "outputs",
    "summaries",
    "bayesflight_v2_risk_scoring_system.txt"
  )
)


# ------------------------------------------------------------
# 22. Final confirmation
# ------------------------------------------------------------

cat("\n====================================================\n")
cat("DELAY-RISK SCORING SYSTEM COMPLETED SUCCESSFULLY!\n")
cat("====================================================\n")

cat("\nSaved scored datasets:\n")
cat("- bayesflight_v2_scored_flights.rds\n")
cat("- bayesflight_v2_scored_flights.csv\n")

cat("\nSaved summary tables:\n")
cat("- bayesflight_v2_risk_thresholds.csv\n")
cat("- bayesflight_v2_risk_level_summary.csv\n")
cat("- bayesflight_v2_alert_priority_summary.csv\n")
cat("- bayesflight_v2_alert_queue.csv\n")

if (nrow(airport_risk_ranking) > 0) {
  cat("- bayesflight_v2_airport_risk_ranking.csv\n")
}

if (nrow(route_risk_ranking) > 0) {
  cat("- bayesflight_v2_route_risk_ranking.csv\n")
}

cat("\nSaved figures:\n")
cat("- bayesflight_v2_risk_distribution.png\n")
cat("- bayesflight_v2_risk_level_calibration.png\n")

cat("\nStep 24 is complete.\n")
cat("====================================================\n")