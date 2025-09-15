# Copy to terraform/backend.hcl and edit values

# GCS backend configuration
# Docs: https://developer.hashicorp.com/terraform/language/settings/backends/gcs

# Required
bucket = "your-tf-state-bucket"      # existing GCS bucket name
prefix = "atlas-rs/state"            # folder/prefix within the bucket

# Authentication (choose one)
# Option A: Use Application Default Credentials (ADC) via gcloud or env
#   gcloud auth application-default login
# Option B: Point to a service account JSON file
# credentials = "/path/to/service-account.json"

# Optional: impersonate a service account (requires gcloud setup)
# impersonate_service_account = "sa-name@project-id.iam.gserviceaccount.com"
