terraform {
  required_version = ">= 1.6.0"

  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.19" # adjust as needed
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # Uncomment & configure a remote backend (recommended for teamwork)
  # Example (GCS):
  # backend "gcs" {
  #   bucket  = "your-tf-state-bucket"
  #   prefix  = "atlas-rs/state"
  # }
}
