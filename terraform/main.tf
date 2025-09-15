#############################
# MongoDB Atlas Project
#############################

locals {
  project_id = var.atlas_project_id
}

#############################
# Advanced (Replica Set) Cluster
#############################

# The advanced cluster resource supports global multi-region replica sets.
resource "mongodbatlas_advanced_cluster" "global_rs" {
  project_id          = local.project_id
  name                = var.cluster_name
  cluster_type        = "REPLICASET"  # Change to SHARDED for one-shard demo
  backup_enabled      = var.cluster_backup_enabled
  pit_enabled         = var.cluster_backup_enabled
  termination_protection_enabled = false
  mongo_db_major_version         = var.mongo_db_major_version

  replication_specs {
    zone_name = "Zone Uno"
    region_configs {
      provider_name = "GCP"
      region_name   = "CENTRAL_US"
      priority      = 7

      electable_specs {
        instance_size = var.cluster_instance_size
        node_count    = 3
      }

      read_only_specs {
        instance_size = var.cluster_instance_size
        node_count    = 0
      }

      analytics_specs {
        instance_size = var.cluster_instance_size
        node_count    = 0
      }
    }

    region_configs {
      provider_name = "GCP"
      region_name   = "AUSTRALIA_SOUTHEAST_1"
      priority      = 6

      electable_specs {
        instance_size = var.cluster_instance_size
        node_count    = 2
      }

      read_only_specs {
        instance_size = var.cluster_instance_size
        node_count    = 0
      }

      analytics_specs {
        instance_size = var.cluster_instance_size
        node_count    = 0
      }
    }
  }
}

# Open Atlas IP Access List for the demo so Cloud Functions (with ephemeral egress IPs)
# can reach the cluster over the public internet. This is gated by a variable and
# should be disabled or replaced with specific NAT IPs for production.
# resource "mongodbatlas_project_ip_access_list" "demo_open" {
#  count      = var.atlas_demo_open_access && local.demo_enabled ? 1 : 0
#  project_id = local.project_id
#  cidr_block = "0.0.0.0/0"
#  comment    = "Demo: allow access from anywhere for Cloud Functions gen2"
# }


#############################
# Outputs / Helpful Data
#############################

data "mongodbatlas_cluster" "conn_strings" {
  project_id = local.project_id
  name       = var.cluster_name
  depends_on = [mongodbatlas_advanced_cluster.global_rs]
}

#############################################
# Optional GCP Demo (static site + Cloud Functions)
#############################################

provider "google" {
  # Intentionally omit project/region to avoid errors when demo disabled.
  # Resources specify project/location explicitly when used.
}

data "mongodbatlas_cluster" "this" {
  project_id = local.project_id
  name       = var.cluster_name
  depends_on = [mongodbatlas_advanced_cluster.global_rs]
}

resource "random_password" "demo_user" {
  count        = 1
  length       = 20
  special      = false   # alphanumeric only
  upper        = true
  lower        = true
  numeric      = true
  min_upper    = 1
  min_lower    = 1
  min_numeric  = 1
}

resource "mongodbatlas_database_user" "demo" {
  count               = 1
  project_id          = local.project_id
  username            = "largeRSTestUser"
  password            = random_password.demo_user[0].result
  auth_database_name  = "admin"
  roles {
    role_name     = "readWrite"
    database_name = "test"
    collection_name = "test"
  }
  labels {
    key   = "description"
    value = "Demo user for cluster ${var.cluster_name}"
  }
  scopes {
    name = var.cluster_name
    type = "CLUSTER"
  }
  lifecycle {
    prevent_destroy = false
  }
  depends_on = [mongodbatlas_advanced_cluster.global_rs]
}

locals {
  generated_demo_uri = (length(try(data.mongodbatlas_cluster.conn_strings.connection_strings[0].standard_srv, "")) > 0) ? replace(
    data.mongodbatlas_cluster.conn_strings.connection_strings[0].standard_srv,
    "mongodb+srv://",
    "mongodb+srv://${mongodbatlas_database_user.demo[0].username}:${urlencode(random_password.demo_user[0].result)}@"
  ) : ""
  effective_mongodb_uri = local.generated_demo_uri
  # Demo deploys in a single apply when a GCP project is provided.
  demo_enabled        = length(var.gcp_project_id) > 0
  demo_bucket_us      = lower(replace("${var.demo_bucket_prefix}-us", "_", "-"))
  demo_bucket_au      = lower(replace("${var.demo_bucket_prefix}-au", "_", "-"))
  demo_app_dir        = "${path.module}/../demo-app"
}

# Shared random suffix to ensure globally-unique bucket names for the demo.
resource "random_id" "demo_bucket_suffix" {
  count       = local.demo_enabled ? 1 : 0
  byte_length = 2 # 4 hex chars
}

resource "google_project_service" "services" {
  # Avoid sensitive gating in for_each by using only non-sensitive vars here.
  for_each = (length(var.gcp_project_id) > 0) ? toset([
    "storage.googleapis.com",
    "run.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com"
  ]) : toset([])
  project  = var.gcp_project_id
  service  = each.key
  disable_on_destroy = false
}

resource "google_storage_bucket" "demo_us" {
  count   = local.demo_enabled ? 1 : 0
  project = var.gcp_project_id
  name    = "${local.demo_bucket_us}-${random_id.demo_bucket_suffix[0].hex}"
  location = var.gcp_primary_region
  uniform_bucket_level_access = true
  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }
}

resource "google_storage_bucket" "demo_au" {
  count   = local.demo_enabled ? 1 : 0
  project = var.gcp_project_id
  name    = "${local.demo_bucket_au}-${random_id.demo_bucket_suffix[0].hex}"
  location = var.gcp_secondary_region
  uniform_bucket_level_access = true
  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }
}

// Render index.html content using built-in templatefile() (no external provider)

resource "google_storage_bucket_object" "index_us" {
  count   = local.demo_enabled ? 1 : 0
  bucket  = google_storage_bucket.demo_us[0].name
  name    = "index.html"
  content = templatefile(
    "${path.module}/templates/index.html.tmpl",
    {
      # template expects milliseconds
      refresh_default_ms      = var.demo_refresh_default_seconds * 1000
      cluster_name            = var.cluster_name
      api_base                = google_cloudfunctions2_function.api_us[0].service_config[0].uri
    }
  )
  content_type = "text/html"
  depends_on = [google_cloudfunctions2_function.api_us]
}

resource "google_storage_bucket_object" "index_au" {
  count   = local.demo_enabled ? 1 : 0
  bucket  = google_storage_bucket.demo_au[0].name
  name    = "index.html"
  content = templatefile(
    "${path.module}/templates/index.html.tmpl",
    {
      refresh_default_ms      = var.demo_refresh_default_seconds * 1000
      cluster_name            = var.cluster_name
      api_base                = google_cloudfunctions2_function.api_au[0].service_config[0].uri
    }
  )
  content_type = "text/html"
  depends_on = [google_cloudfunctions2_function.api_au]
}

resource "google_storage_bucket_iam_binding" "public_us" {
  count   = local.demo_enabled ? 1 : 0
  bucket  = google_storage_bucket.demo_us[0].name
  role    = "roles/storage.objectViewer"
  members = ["allUsers"]
}

resource "google_storage_bucket_iam_binding" "public_au" {
  count   = local.demo_enabled ? 1 : 0
  bucket  = google_storage_bucket.demo_au[0].name
  role    = "roles/storage.objectViewer"
  members = ["allUsers"]
}

#############################
# Cloud Functions (v2) HTTP API
#############################

data "archive_file" "gcf_src" {
  count       = local.demo_enabled ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/gcp_functions"
  output_path = "${path.module}/gcf_src.zip"
}

resource "google_storage_bucket" "gcf_src" {
  count                         = local.demo_enabled ? 1 : 0
  name                          = "${lower(replace("${var.demo_bucket_prefix}-gcf-src", "_", "-"))}-${random_id.demo_bucket_suffix[0].hex}"
  project                       = var.gcp_project_id
  location                      = var.gcp_primary_region
  uniform_bucket_level_access   = true
}

resource "google_storage_bucket_object" "gcf_src" {
  count   = local.demo_enabled ? 1 : 0
  bucket  = google_storage_bucket.gcf_src[0].name
  name    = "source-${data.archive_file.gcf_src[0].output_sha}.zip"
  source  = data.archive_file.gcf_src[0].output_path
  content_type = "application/zip"
}

resource "google_cloudfunctions2_function" "api_us" {
  count    = local.demo_enabled ? 1 : 0
  project  = var.gcp_project_id
  name     = "atlas-rs-demo-us"
  location = var.gcp_primary_region

  build_config {
    runtime     = "nodejs22"
    entry_point = "handler"
    source {
      storage_source {
        bucket = google_storage_bucket.gcf_src[0].name
        object = google_storage_bucket_object.gcf_src[0].name
      }
    }
  }

  service_config {
    environment_variables = {
      MONGODB_URI    = nonsensitive(local.effective_mongodb_uri)
      READ_PREFERENCE = var.demo_read_preference
    }
    timeout_seconds = var.cloud_run_timeout_seconds
    ingress_settings = "ALLOW_ALL"
  }

  depends_on = [google_project_service.services]
}

resource "google_cloudfunctions2_function" "api_au" {
  count    = local.demo_enabled ? 1 : 0
  project  = var.gcp_project_id
  name     = "atlas-rs-demo-au"
  location = var.gcp_secondary_region

  build_config {
    runtime     = "nodejs22"
    entry_point = "handler"
    source {
      storage_source {
        bucket = google_storage_bucket.gcf_src[0].name
        object = google_storage_bucket_object.gcf_src[0].name
      }
    }
  }

  service_config {
    environment_variables = {
      MONGODB_URI    = nonsensitive(local.effective_mongodb_uri)
      READ_PREFERENCE = var.demo_read_preference
    }
    timeout_seconds = var.cloud_run_timeout_seconds
    ingress_settings = "ALLOW_ALL"
  }

  depends_on = [google_project_service.services]
}

resource "google_cloud_run_v2_service_iam_member" "invoker_us" {
  count    = local.demo_enabled ? 1 : 0
  project  = var.gcp_project_id
  location = var.gcp_primary_region
  name     = google_cloudfunctions2_function.api_us[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "invoker_au" {
  count    = local.demo_enabled ? 1 : 0
  project  = var.gcp_project_id
  location = var.gcp_secondary_region
  name     = google_cloudfunctions2_function.api_au[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
