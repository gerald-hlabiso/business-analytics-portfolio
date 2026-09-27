# ============================================================
# Project: BayesFlight
# Description: Bayesian Flight-Delay Decision-Support System
# Script: 01_setup.R
# ============================================================

required_packages <- c(
  "tidyverse",
  "data.table",
  "lubridate",
  "janitor",
  "scales",
  "here",
  "skimr"
)

packages_to_install <- required_packages[
  !required_packages %in% rownames(installed.packages())
]

if (length(packages_to_install) > 0) {
  install.packages(packages_to_install)
}

invisible(
  lapply(
    required_packages,
    library,
    character.only = TRUE
  )
)

cat("BayesFlight setup completed successfully!\n")
