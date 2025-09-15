# GCS backend configuration for this project
# Uses the shared bucket for Terraform remote state.

bucket = "replication_track_terraform_backend"
prefix = "large-rs/state"

# Authentication
# Prefer Application Default Credentials (ADC):
#   gcloud auth application-default login
# Or point to a service account JSON:
# credentials = "/path/to/service-account.json"
