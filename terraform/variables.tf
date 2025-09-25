variable "atlas_project_id" {
  type        = string
  description = "Existing MongoDB Atlas Project ID (24-hex). Required."
  default     = ""
  validation {
    condition     = length(var.atlas_project_id) > 0 && length(regexall("^[a-f0-9]{24}$", var.atlas_project_id)) > 0
    error_message = "Set TF_VAR_atlas_project_id to a valid 24-character hex Atlas Project ID."
  }
}

// Cloud variables consolidated for GCP-only deployment.

variable "cluster_name" {
  type        = string
  description = "Name of the Atlas cluster (advanced / replica set)."
  default     = "global-rs"
}


variable "cluster_instance_size" {
  type        = string
  description = "Atlas instance size (e.g. M10, M30). Use M30+ for multi-region replica sets."
  default     = "M30"

}

variable "cluster_backup_enabled" {
  type        = bool
  description = "Enable cloud backups (Continuous Backup / PITR)."
  default     = true
}

variable "mongo_db_major_version" {
  type        = string
  description = "MongoDB major version for the advanced cluster (e.g. 7.0, 6.0)."
  default     = "7.0"
}

# =============================
# GCP Demo App (Optional)
# =============================
// Demo is always enabled; no flag required.

variable "gcp_project_id" {
  type        = string
  description = "Target GCP project ID for demo resources."
  default     = ""
}

variable "gcp_primary_region" {
  type        = string
  description = "Primary GCP region (e.g. us-east1)."
  default     = "us-east1"
}

variable "gcp_secondary_region" {
  type        = string
  description = "Secondary GCP region (e.g. australia-southeast1)."
  default     = "australia-southeast1"
}

variable "demo_bucket_prefix" {
  type        = string
  description = "Prefix for GCS buckets (suffix -us/-au)."
  default     = "atlas-rs-greetings"
}

variable "demo_refresh_default_seconds" {
  type        = number
  description = "Default polling refresh interval seconds."
  default     = 5
}
// Demo now always generates its own credentials and URI once the cluster is ready.
// Docker / Cloud Run image variables removed in favor of Cloud Functions v2

variable "cloud_run_timeout_seconds" {
  type        = number
  description = "Request timeout seconds for the function."
  default     = 10
}

# Allow the demo to connect to Atlas by opening project IP access list to the internet.
# For production, set this to false and allow only specific egress IPs.
# variable "atlas_demo_open_access" {
#   type        = bool
#   description = "If true, add 0.0.0.0/0 to Atlas Project IP Access List so Cloud Functions can connect."
#   default     = true
# }

variable "demo_read_preference" {
  type        = string
  description = "Read preference for demo reads: one of primary, primaryPreferred, secondary, secondaryPreferred, nearest."
  default     = "primary"
  validation {
    condition     = contains(["primary","primaryPreferred","secondary","secondaryPreferred","nearest"], var.demo_read_preference)
    error_message = "demo_read_preference must be one of primary, primaryPreferred, secondary, secondaryPreferred, nearest."
  }
}
