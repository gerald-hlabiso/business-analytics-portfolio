# ============================================================
# 25_prepare_power_bi_data.R
# Prepare dashboard-ready BayesFlight data for Power BI
# ============================================================


# ------------------------------------------------------------
# 1. Load packages
# ------------------------------------------------------------

library(tidyverse)
library(here)

options(error = NULL)


# ------------------------------------------------------------
# 2. Create Power BI output folder
# ------------------------------------------------------------

power_bi_folder <- here(
  "outputs",
  "power_bi"
)

dir.create(
  power_bi_folder,
  recursive = TRUE,
  showWarnings = FALSE
)


# ------------------------------------------------------------
# 3. Define required input files
# ------------------------------------------------------------

scored_data_path <- here(
  "data",
  "processed",
  "bayesflight_v2_scored_flights.rds"
)

coefficient_path <- here(
  "outputs",
  "tables",
  "bayesflight_v2_coefficient_interpretation.csv"
)

performance_path <- here(
  "outputs",
  "tables",
  "bayesflight_v2_chronological_performance.csv"
)

risk_summary_path <- here(
  "outputs",
  "tables",
  "bayesflight_v2_risk_level_summary.csv"
)

alert_summary_path <- here(
  "outputs",
  "tables",
  "bayesflight_v2_alert_priority_summary.csv"
)

airport_ranking_path <- here(
  "outputs",
  "tables",
  "bayesflight_v2_airport_risk_ranking.csv"
)

risk_threshold_path <- here(
  "outputs",
  "tables",
  "bayesflight_v2_risk_thresholds.csv"
)


# ------------------------------------------------------------
# 4. Check the scored dataset
# ------------------------------------------------------------

if (!file.exists(scored_data_path)) {
  stop(
    paste(
      "Scored dataset not found:",
      scored_data_path,
      "\nRun Script 24 first."
    )
  )
}


# ------------------------------------------------------------
# 5. Load scored data
# ------------------------------------------------------------

scored_flights <- readRDS(
  scored_data_path
)

cat("\n====================================================\n")
cat("PREPARING BAYESFLIGHT POWER BI DATA\n")
cat("====================================================\n")

cat(
  "\nScored rows loaded:",
  nrow(scored_flights),
  "\n"
)


# ------------------------------------------------------------
# 6. Convert factors into Power BI-friendly text
# ------------------------------------------------------------

power_bi_fact <- scored_flights |>
  mutate(
    across(
      where(is.factor),
      as.character
    )
  )


# ------------------------------------------------------------
# 7. Add record identifiers
# ------------------------------------------------------------

power_bi_fact <- power_bi_fact |>
  mutate(
    flight_risk_record_id =
      row_number(),
    
    origin = if (
      "origin" %in% names(power_bi_fact)
    ) {
      as.character(origin)
    } else {
      NA_character_
    },
    
    destination = if (
      "destination" %in% names(power_bi_fact)
    ) {
      as.character(destination)
    } else {
      NA_character_
    },
    
    route = if_else(
      !is.na(origin) &
        !is.na(destination),
      
      paste(
        origin,
        destination,
        sep = " → "
      ),
      
      NA_character_
    )
  )


# ------------------------------------------------------------
# 8. Add Power BI sorting columns
# ------------------------------------------------------------

power_bi_fact <- power_bi_fact |>
  mutate(
    risk_level_sort = case_when(
      risk_level == "Low" ~ 1L,
      risk_level == "Moderate" ~ 2L,
      risk_level == "High" ~ 3L,
      risk_level == "Severe" ~ 4L,
      TRUE ~ NA_integer_
    ),
    
    alert_priority_sort = case_when(
      alert_priority == "Routine" ~ 1L,
      alert_priority == "Priority 3" ~ 2L,
      alert_priority == "Priority 2" ~ 3L,
      alert_priority == "Priority 1" ~ 4L,
      TRUE ~ NA_integer_
    ),
    
    uncertainty_level_sort = case_when(
      uncertainty_level == "Low" ~ 1L,
      uncertainty_level == "Moderate" ~ 2L,
      uncertainty_level == "High" ~ 3L,
      uncertainty_level == "Unavailable" ~ 4L,
      TRUE ~ NA_integer_
    )
  )


# ------------------------------------------------------------
# 9. Add display labels
# ------------------------------------------------------------

power_bi_fact <- power_bi_fact |>
  mutate(
    predicted_delay_percent = round(
      predicted_probability * 100,
      1
    ),
    
    observed_delay_percent = round(
      observed_delay_rate * 100,
      1
    ),
    
    risk_display = paste0(
      risk_level,
      " (",
      format(
        delay_risk_score,
        nsmall = 1
      ),
      ")"
    ),
    
    operational_status = case_when(
      risk_level == "Low" ~
        "Normal",
      
      risk_level == "Moderate" ~
        "Monitor",
      
      risk_level == "High" ~
        "Mitigation required",
      
      risk_level == "Severe" ~
        "Immediate attention",
      
      TRUE ~
        "Unknown"
    )
  )


# ------------------------------------------------------------
# 10. Add month labels when month exists
# ------------------------------------------------------------

if ("month" %in% names(power_bi_fact)) {
  
  power_bi_fact <- power_bi_fact |>
    mutate(
      month_number = suppressWarnings(
        as.integer(
          as.character(month)
        )
      ),
      
      month_name = case_when(
        month_number %in% 1:12 ~
          month.name[month_number],
        
        TRUE ~
          as.character(month)
      ),
      
      month_short_name = case_when(
        month_number %in% 1:12 ~
          month.abb[month_number],
        
        TRUE ~
          as.character(month)
      )
    )
}


# ------------------------------------------------------------
# 11. Add a calendar month when year and month exist
# ------------------------------------------------------------

if (
  all(
    c(
      "year",
      "month_number"
    ) %in% names(power_bi_fact)
  )
) {
  
  power_bi_fact <- power_bi_fact |>
    mutate(
      calendar_month = as.Date(
        paste0(
          as.integer(year),
          "-",
          sprintf(
            "%02d",
            month_number
          ),
          "-01"
        )
      )
    )
}


# ------------------------------------------------------------
# 12. Create risk-level dimension
# ------------------------------------------------------------

risk_dimension <- tibble(
  risk_level = c(
    "Low",
    "Moderate",
    "High",
    "Severe"
  ),
  
  risk_level_sort = c(
    1L,
    2L,
    3L,
    4L
  ),
  
  minimum_risk_score = c(
    0,
    15,
    25,
    40
  ),
  
  maximum_risk_score = c(
    14.9,
    24.9,
    39.9,
    100
  ),
  
  risk_color = c(
    "#2E86DE",
    "#F1C40F",
    "#E67E22",
    "#D64545"
  ),
  
  recommended_action = c(
    "Normal monitoring",
    "Monitor operating conditions",
    "Review and prepare mitigation",
    "Immediate operational attention"
  )
)


# ------------------------------------------------------------
# 13. Create alert-priority dimension
# ------------------------------------------------------------

alert_priority_dimension <- tibble(
  alert_priority = c(
    "Routine",
    "Priority 3",
    "Priority 2",
    "Priority 1"
  ),
  
  alert_priority_sort = c(
    1L,
    2L,
    3L,
    4L
  ),
  
  priority_description = c(
    "Normal operational monitoring",
    "Additional monitoring recommended",
    "Operational review required",
    "Immediate operational response required"
  ),
  
  priority_color = c(
    "#2E86DE",
    "#F1C40F",
    "#E67E22",
    "#D64545"
  )
)


# ------------------------------------------------------------
# 14. Create airport dimension
# ------------------------------------------------------------

airport_values <- unique(
  c(
    power_bi_fact$origin,
    power_bi_fact$destination
  )
)

airport_dimension <- tibble(
  airport_code = airport_values
) |>
  filter(
    !is.na(airport_code),
    airport_code != ""
  ) |>
  distinct() |>
  arrange(
    airport_code
  ) |>
  mutate(
    airport_key = row_number()
  ) |>
  select(
    airport_key,
    airport_code
  )


# ------------------------------------------------------------
# 15. Create route dimension
# ------------------------------------------------------------

route_dimension <- power_bi_fact |>
  filter(
    !is.na(origin),
    !is.na(destination)
  ) |>
  distinct(
    origin,
    destination,
    route
  ) |>
  arrange(
    origin,
    destination
  ) |>
  mutate(
    route_key = row_number()
  ) |>
  select(
    route_key,
    origin,
    destination,
    route
  )


# ------------------------------------------------------------
# 16. Create data-split dimension
# ------------------------------------------------------------

data_split_dimension <- power_bi_fact |>
  distinct(
    data_split
  ) |>
  mutate(
    data_split_sort = case_when(
      data_split == "Training" ~ 1L,
      data_split == "Validation" ~ 2L,
      data_split == "Testing" ~ 3L,
      TRUE ~ 4L
    )
  ) |>
  arrange(
    data_split_sort
  )


# ------------------------------------------------------------
# 17. Create overall KPI summary
# ------------------------------------------------------------

split_names <- unique(
  power_bi_fact$data_split
)

kpi_list <- lapply(
  split_names,
  function(current_split) {
    
    split_data <- power_bi_fact |>
      filter(
        data_split == current_split
      )
    
    total_flights_value <- sum(
      split_data$total_flights,
      na.rm = TRUE
    )
    
    delayed_flights_value <- sum(
      split_data$delayed_flights,
      na.rm = TRUE
    )
    
    predicted_rate_value <- weighted.mean(
      split_data$predicted_probability,
      w = split_data$total_flights,
      na.rm = TRUE
    )
    
    observed_rate_value <-
      delayed_flights_value /
      total_flights_value
    
    high_risk_flights_value <- sum(
      split_data$total_flights[
        split_data$risk_level %in%
          c(
            "High",
            "Severe"
          )
      ],
      na.rm = TRUE
    )
    
    severe_risk_flights_value <- sum(
      split_data$total_flights[
        split_data$risk_level ==
          "Severe"
      ],
      na.rm = TRUE
    )
    
    priority_alert_flights_value <- sum(
      split_data$total_flights[
        split_data$alert_priority %in%
          c(
            "Priority 1",
            "Priority 2"
          )
      ],
      na.rm = TRUE
    )
    
    tibble(
      data_split = current_split,
      
      total_flights =
        total_flights_value,
      
      delayed_flights =
        delayed_flights_value,
      
      observed_delay_rate =
        observed_rate_value,
      
      predicted_delay_rate =
        predicted_rate_value,
      
      calibration_gap =
        predicted_rate_value -
        observed_rate_value,
      
      average_risk_score = weighted.mean(
        split_data$delay_risk_score,
        w = split_data$total_flights,
        na.rm = TRUE
      ),
      
      high_or_severe_risk_flights =
        high_risk_flights_value,
      
      severe_risk_flights =
        severe_risk_flights_value,
      
      priority_alert_flights =
        priority_alert_flights_value,
      
      high_or_severe_share =
        high_risk_flights_value /
        total_flights_value,
      
      severe_risk_share =
        severe_risk_flights_value /
        total_flights_value,
      
      priority_alert_share =
        priority_alert_flights_value /
        total_flights_value
    )
  }
)

dashboard_kpi_summary <- bind_rows(
  kpi_list
)

cat("\n====================================================\n")
cat("POWER BI KPI SUMMARY\n")
cat("====================================================\n")

print(
  dashboard_kpi_summary,
  n = Inf,
  width = Inf
)


# ------------------------------------------------------------
# 18. Create risk-level dashboard summary
# ------------------------------------------------------------

dashboard_risk_summary <- power_bi_fact |>
  group_by(
    data_split,
    risk_level,
    risk_level_sort
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
  group_by(
    data_split
  ) |>
  mutate(
    observed_delay_rate =
      group_delayed_flights /
      group_total_flights,
    
    calibration_gap =
      predicted_delay_rate -
      observed_delay_rate,
    
    share_of_split_flights =
      group_total_flights /
      sum(group_total_flights)
  ) |>
  ungroup() |>
  transmute(
    data_split,
    risk_level,
    risk_level_sort,
    
    total_flights =
      group_total_flights,
    
    delayed_flights =
      group_delayed_flights,
    
    number_of_records,
    share_of_split_flights,
    observed_delay_rate,
    predicted_delay_rate,
    calibration_gap
  )


# ------------------------------------------------------------
# 19. Create operational-condition summary
# ------------------------------------------------------------

operational_dimensions <- intersect(
  c(
    "weather_severity",
    "operational_congestion",
    "departure_period",
    "distance_band",
    "month_name"
  ),
  names(power_bi_fact)
)

operational_summary_list <- lapply(
  operational_dimensions,
  function(current_dimension) {
    
    prepared_dimension_data <- power_bi_fact |>
      filter(
        !is.na(
          .data[[current_dimension]]
        )
      ) |>
      mutate(
        category = as.character(
          .data[[current_dimension]]
        )
      )
    
    prepared_dimension_data |>
      group_by(
        data_split,
        category
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
      mutate(
        operational_dimension =
          current_dimension,
        
        observed_delay_rate =
          group_delayed_flights /
          group_total_flights,
        
        calibration_gap =
          predicted_delay_rate -
          observed_delay_rate
      ) |>
      transmute(
        operational_dimension,
        data_split,
        category,
        
        total_flights =
          group_total_flights,
        
        delayed_flights =
          group_delayed_flights,
        
        observed_delay_rate,
        predicted_delay_rate,
        calibration_gap
      )
  }
)

if (length(operational_summary_list) > 0) {
  
  dashboard_operational_summary <- bind_rows(
    operational_summary_list
  )
  
} else {
  
  dashboard_operational_summary <- tibble(
    operational_dimension = character(),
    data_split = character(),
    category = character(),
    total_flights = numeric(),
    delayed_flights = numeric(),
    observed_delay_rate = numeric(),
    predicted_delay_rate = numeric(),
    calibration_gap = numeric()
  )
}


# ------------------------------------------------------------
# 20. Create airport dashboard summary
# ------------------------------------------------------------

dashboard_airport_summary <- power_bi_fact |>
  filter(
    !is.na(origin),
    origin != ""
  ) |>
  group_by(
    data_split,
    origin
  ) |>
  summarise(
    predicted_delay_rate = weighted.mean(
      predicted_probability,
      w = total_flights,
      na.rm = TRUE
    ),
    
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
    
    high_risk_flights = sum(
      total_flights[
        risk_level %in%
          c(
            "High",
            "Severe"
          )
      ],
      na.rm = TRUE
    ),
    
    severe_risk_flights = sum(
      total_flights[
        risk_level == "Severe"
      ],
      na.rm = TRUE
    ),
    
    .groups = "drop"
  ) |>
  mutate(
    observed_delay_rate =
      group_delayed_flights /
      group_total_flights,
    
    calibration_gap =
      predicted_delay_rate -
      observed_delay_rate,
    
    high_risk_share =
      high_risk_flights /
      group_total_flights,
    
    severe_risk_share =
      severe_risk_flights /
      group_total_flights
  ) |>
  group_by(
    data_split
  ) |>
  arrange(
    desc(average_risk_score),
    .by_group = TRUE
  ) |>
  mutate(
    airport_risk_rank =
      row_number()
  ) |>
  ungroup() |>
  rename(
    airport_code = origin,
    
    total_flights =
      group_total_flights,
    
    delayed_flights =
      group_delayed_flights
  )


# ------------------------------------------------------------
# 21. Create route dashboard summary
# ------------------------------------------------------------

dashboard_route_summary <- power_bi_fact |>
  filter(
    !is.na(origin),
    !is.na(destination)
  ) |>
  group_by(
    data_split,
    origin,
    destination,
    route
  ) |>
  summarise(
    predicted_delay_rate = weighted.mean(
      predicted_probability,
      w = total_flights,
      na.rm = TRUE
    ),
    
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
    
    .groups = "drop"
  ) |>
  mutate(
    observed_delay_rate =
      group_delayed_flights /
      group_total_flights,
    
    calibration_gap =
      predicted_delay_rate -
      observed_delay_rate
  ) |>
  group_by(
    data_split
  ) |>
  arrange(
    desc(average_risk_score),
    .by_group = TRUE
  ) |>
  mutate(
    route_risk_rank =
      row_number()
  ) |>
  ungroup() |>
  rename(
    total_flights =
      group_total_flights,
    
    delayed_flights =
      group_delayed_flights
  )


# ------------------------------------------------------------
# 22. Create Power BI alert queue
# ------------------------------------------------------------

power_bi_alert_queue <- power_bi_fact |>
  filter(
    alert_priority %in%
      c(
        "Priority 1",
        "Priority 2"
      )
  ) |>
  arrange(
    desc(alert_priority_sort),
    desc(delay_risk_score),
    desc(total_flights)
  ) |>
  mutate(
    alert_rank =
      row_number()
  )


# ------------------------------------------------------------
# 23. Load supporting model tables when available
# ------------------------------------------------------------

if (file.exists(coefficient_path)) {
  
  power_bi_coefficients <- read_csv(
    coefficient_path,
    show_col_types = FALSE
  )
  
} else {
  
  power_bi_coefficients <- tibble()
}

if (file.exists(performance_path)) {
  
  power_bi_model_performance <- read_csv(
    performance_path,
    show_col_types = FALSE
  )
  
} else {
  
  power_bi_model_performance <- tibble()
}


# ------------------------------------------------------------
# 24. Create Power BI table catalog
# ------------------------------------------------------------

table_catalog <- tibble(
  table_name = c(
    "fact_flight_risk_scores",
    "dim_risk_level",
    "dim_alert_priority",
    "dim_airport",
    "dim_route",
    "dim_data_split",
    "summary_dashboard_kpis",
    "summary_risk_levels",
    "summary_operational_conditions",
    "summary_airports",
    "summary_routes",
    "fact_alert_queue",
    "model_coefficients",
    "model_performance"
  ),
  
  table_type = c(
    "Fact",
    "Dimension",
    "Dimension",
    "Dimension",
    "Dimension",
    "Dimension",
    "Summary",
    "Summary",
    "Summary",
    "Summary",
    "Summary",
    "Fact",
    "Model output",
    "Model output"
  ),
  
  description = c(
    "Detailed scored flight-risk records",
    "Risk tiers, thresholds, colors, and actions",
    "Alert priorities and descriptions",
    "Unique airport codes",
    "Unique origin-destination routes",
    "Training, validation, and testing splits",
    "Top-level dashboard KPI values",
    "Performance by Bayesian risk tier",
    "Performance by operating condition",
    "Origin-airport delay-risk rankings",
    "Route delay-risk rankings",
    "Priority 1 and Priority 2 alert records",
    "Posterior coefficient and odds-ratio results",
    "Chronological model-performance results"
  )
)


# ------------------------------------------------------------
# 25. Save Power BI fact and dimension tables
# ------------------------------------------------------------

write_csv(
  power_bi_fact,
  file.path(
    power_bi_folder,
    "fact_flight_risk_scores.csv"
  )
)

write_csv(
  risk_dimension,
  file.path(
    power_bi_folder,
    "dim_risk_level.csv"
  )
)

write_csv(
  alert_priority_dimension,
  file.path(
    power_bi_folder,
    "dim_alert_priority.csv"
  )
)

write_csv(
  airport_dimension,
  file.path(
    power_bi_folder,
    "dim_airport.csv"
  )
)

write_csv(
  route_dimension,
  file.path(
    power_bi_folder,
    "dim_route.csv"
  )
)

write_csv(
  data_split_dimension,
  file.path(
    power_bi_folder,
    "dim_data_split.csv"
  )
)


# ------------------------------------------------------------
# 26. Save Power BI summary tables
# ------------------------------------------------------------

write_csv(
  dashboard_kpi_summary,
  file.path(
    power_bi_folder,
    "summary_dashboard_kpis.csv"
  )
)

write_csv(
  dashboard_risk_summary,
  file.path(
    power_bi_folder,
    "summary_risk_levels.csv"
  )
)

write_csv(
  dashboard_operational_summary,
  file.path(
    power_bi_folder,
    "summary_operational_conditions.csv"
  )
)

write_csv(
  dashboard_airport_summary,
  file.path(
    power_bi_folder,
    "summary_airports.csv"
  )
)

write_csv(
  dashboard_route_summary,
  file.path(
    power_bi_folder,
    "summary_routes.csv"
  )
)

write_csv(
  power_bi_alert_queue,
  file.path(
    power_bi_folder,
    "fact_alert_queue.csv"
  )
)


# ------------------------------------------------------------
# 27. Save supporting model tables
# ------------------------------------------------------------

if (nrow(power_bi_coefficients) > 0) {
  
  write_csv(
    power_bi_coefficients,
    file.path(
      power_bi_folder,
      "model_coefficients.csv"
    )
  )
}

if (nrow(power_bi_model_performance) > 0) {
  
  write_csv(
    power_bi_model_performance,
    file.path(
      power_bi_folder,
      "model_performance.csv"
    )
  )
}

write_csv(
  table_catalog,
  file.path(
    power_bi_folder,
    "power_bi_table_catalog.csv"
  )
)


# ------------------------------------------------------------
# 28. Save dashboard build instructions
# ------------------------------------------------------------

dashboard_instructions <- c(
  "BAYESFLIGHT POWER BI DASHBOARD DATA",
  "===================================",
  "",
  "Recommended dashboard pages:",
  "",
  "1. Executive Overview",
  "   - Total flights",
  "   - Observed delay rate",
  "   - Predicted delay rate",
  "   - Average risk score",
  "   - High/Severe risk share",
  "   - Priority alert share",
  "",
  "2. Risk Monitoring",
  "   - Flights by risk level",
  "   - Observed versus predicted delay rate",
  "   - Risk level by weather severity",
  "   - Risk level by congestion",
  "",
  "3. Airport and Route Risk",
  "   - Highest-risk airports",
  "   - Highest-risk routes",
  "   - Airport delay-rate comparison",
  "",
  "4. Operational Alert Queue",
  "   - Priority 1 and Priority 2 alerts",
  "   - Recommended operational actions",
  "",
  "5. Model Performance",
  "   - Chronological validation metrics",
  "   - Calibration gap",
  "   - Posterior odds ratios",
  "",
  "Recommended relationships:",
  "fact_flight_risk_scores[risk_level] to dim_risk_level[risk_level]",
  "fact_flight_risk_scores[alert_priority] to dim_alert_priority[alert_priority]",
  "fact_flight_risk_scores[data_split] to dim_data_split[data_split]",
  "fact_flight_risk_scores[route] to dim_route[route]",
  "",
  "Use risk_level_sort to sort risk_level.",
  "Use alert_priority_sort to sort alert_priority."
)

writeLines(
  dashboard_instructions,
  file.path(
    power_bi_folder,
    "POWER_BI_BUILD_GUIDE.txt"
  )
)


# ------------------------------------------------------------
# 29. Final confirmation
# ------------------------------------------------------------

cat("\n====================================================\n")
cat("POWER BI DATA PREPARATION COMPLETED SUCCESSFULLY!\n")
cat("====================================================\n")

cat("\nOutput folder:\n")
cat(
  power_bi_folder,
  "\n"
)

cat("\nCore Power BI tables:\n")
cat("- fact_flight_risk_scores.csv\n")
cat("- dim_risk_level.csv\n")
cat("- dim_alert_priority.csv\n")
cat("- dim_airport.csv\n")
cat("- dim_route.csv\n")
cat("- dim_data_split.csv\n")
cat("- summary_dashboard_kpis.csv\n")
cat("- summary_risk_levels.csv\n")
cat("- summary_operational_conditions.csv\n")
cat("- summary_airports.csv\n")
cat("- summary_routes.csv\n")
cat("- fact_alert_queue.csv\n")
cat("- model_coefficients.csv\n")
cat("- model_performance.csv\n")
cat("- power_bi_table_catalog.csv\n")
cat("- POWER_BI_BUILD_GUIDE.txt\n")

cat("\nStep 25 is complete.\n")
cat("====================================================\n")