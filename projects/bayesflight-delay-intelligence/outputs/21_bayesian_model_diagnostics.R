# ============================================================
# BayesFlight: Bayesian Model Diagnostics — V2
# ============================================================

library(rstanarm)
library(posterior)
library(dplyr)
library(readr)
library(here)

# 1. Load the improved model
model_path <- here(
  "models",
  "bayesflight_combined_bayesian_model_v2.rds"
)

if (!file.exists(model_path)) {
  stop("The V2 Bayesian model file could not be found.")
}

bayesflight_model <- readRDS(model_path)

cat("Bayesian V2 model loaded successfully!\n\n")

# 2. Extract posterior draws
posterior_draws <- posterior::as_draws_array(
  as.array(bayesflight_model)
)

cat(
  "Posterior draws:",
  posterior::ndraws(posterior_draws),
  "\n"
)

cat(
  "Parameters:",
  posterior::nvariables(posterior_draws),
  "\n\n"
)

# 3. Calculate convergence diagnostics
diagnostic_summary <- posterior::summarise_draws(
  posterior_draws,
  mean,
  sd,
  median,
  rhat,
  ess_bulk,
  ess_tail
)

parameter_diagnostics <- diagnostic_summary |>
  filter(
    !variable %in% c(
      "lp__",
      "accept_stat__",
      "stepsize__",
      "treedepth__",
      "n_leapfrog__",
      "divergent__",
      "energy__"
    )
  )

maximum_rhat <- max(
  parameter_diagnostics$rhat,
  na.rm = TRUE
)

minimum_bulk_ess <- min(
  parameter_diagnostics$ess_bulk,
  na.rm = TRUE
)

minimum_tail_ess <- min(
  parameter_diagnostics$ess_tail,
  na.rm = TRUE
)

# 4. Check sampler behavior
sampler_parameters <- rstan::get_sampler_params(
  bayesflight_model$stanfit,
  inc_warmup = FALSE
)

total_divergences <- sum(
  vapply(
    sampler_parameters,
    function(chain) sum(chain[, "divergent__"]),
    numeric(1)
  )
)

maximum_tree_depth_observed <- max(
  vapply(
    sampler_parameters,
    function(chain) max(chain[, "treedepth__"]),
    numeric(1)
  )
)

# 5. Print the diagnostic summary
cat("====================================================\n")
cat("BAYESFLIGHT V2 MODEL DIAGNOSTICS\n")
cat("====================================================\n")

cat("Maximum R-hat:", round(maximum_rhat, 4), "\n")
cat("Minimum bulk ESS:", round(minimum_bulk_ess, 1), "\n")
cat("Minimum tail ESS:", round(minimum_tail_ess, 1), "\n")
cat("Divergent transitions:", total_divergences, "\n")
cat("Maximum tree depth observed:", maximum_tree_depth_observed, "\n\n")

cat(
  "R-hat check:",
  ifelse(maximum_rhat <= 1.01, "PASSED", "NEEDS ATTENTION"),
  "\n"
)

cat(
  "Bulk ESS check:",
  ifelse(minimum_bulk_ess >= 400, "PASSED", "NEEDS ATTENTION"),
  "\n"
)

cat(
  "Tail ESS check:",
  ifelse(minimum_tail_ess >= 400, "PASSED", "NEEDS ATTENTION"),
  "\n"
)

cat(
  "Divergence check:",
  ifelse(total_divergences == 0, "PASSED", "NEEDS ATTENTION"),
  "\n"
)

# 6. Display any problematic parameters
problem_parameters <- parameter_diagnostics |>
  filter(
    rhat > 1.01 |
      ess_bulk < 400 |
      ess_tail < 400
  ) |>
  arrange(desc(rhat))

cat("\nParameters requiring attention:\n")

if (nrow(problem_parameters) == 0) {
  cat("None\n")
} else {
  print(problem_parameters, n = Inf, width = Inf)
}

# 7. Save diagnostics
write_csv(
  diagnostic_summary,
  here(
    "outputs",
    "tables",
    "bayesian_model_diagnostics_v2.csv"
  )
)

# 8. Final conclusion
diagnostics_passed <- (
  maximum_rhat <= 1.01 &&
    minimum_bulk_ess >= 400 &&
    minimum_tail_ess >= 400 &&
    total_divergences == 0
)

cat("\n====================================================\n")

if (diagnostics_passed) {
  cat("FINAL RESULT: MODEL DIAGNOSTICS PASSED!\n")
  cat("The V2 model is ready for validation and testing.\n")
} else {
  cat("FINAL RESULT: SOME DIAGNOSTICS NEED ATTENTION.\n")
}

cat("====================================================\n")