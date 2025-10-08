#############################
# MongoDB Atlas Project
#############################

locals {
  project_id = var.atlas_project_id
  # Global random suffix to ensure resource name uniqueness
  cluster_name_effective = "${var.cluster_name}-${random_id.demo_suffix.hex}"
}

#############################
# Advanced (Replica Set) Cluster
#############################

# The advanced cluster resource supports global multi-region replica sets.
resource "mongodbatlas_advanced_cluster" "global_rs" {
  project_id          = local.project_id
  name                = local.cluster_name_effective
  cluster_type        = "REPLICASET"  # Change to SHARDED for one-shard demo
  backup_enabled      = var.cluster_backup_enabled
  pit_enabled         = var.cluster_backup_enabled
  termination_protection_enabled = false
  mongo_db_major_version         = var.mongo_db_major_version

  replication_specs {
    zone_name = "Zone Uno"
    region_configs {
      provider_name = "AWS"
      region_name   = "US_EAST_1"
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
      provider_name = "AWS"
      region_name   = "US_EAST_2"
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

    region_configs {
      provider_name = "AWS"
      region_name   = "AP_SOUTHEAST_2"
      priority      = 0

      electable_specs {
        instance_size = var.cluster_instance_size
        node_count    = 0
      }

      read_only_specs {
        instance_size = var.cluster_instance_size
        node_count    = 1
      }

      analytics_specs {
        instance_size = var.cluster_instance_size
        node_count    = 0
      }
    }
  }
}


#############################
# Outputs / Helpful Data
#############################

data "mongodbatlas_cluster" "conn_strings" {
  project_id = local.project_id
  name       = local.cluster_name_effective
  depends_on = [mongodbatlas_advanced_cluster.global_rs]
}

locals {
  generated_demo_uri = (length(try(data.mongodbatlas_cluster.conn_strings.connection_strings[0].standard_srv, "")) > 0) ? replace(
    data.mongodbatlas_cluster.conn_strings.connection_strings[0].standard_srv,
    "mongodb+srv://",
    "mongodb+srv://${mongodbatlas_database_user.demo[0].username}:${urlencode(random_password.demo_user[0].result)}@"
  ) : ""
  effective_mongodb_uri = local.generated_demo_uri
}

# Shared random suffix to ensure globally-unique names across resources
resource "random_id" "demo_suffix" {
  byte_length = 2 # 4 hex chars
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
    database_name = "architect_day"
  }
  labels {
    key   = "description"
    value = "Demo user for cluster ${local.cluster_name_effective}"
  }
  scopes {
    name = local.cluster_name_effective
    type = "CLUSTER"
  }
  lifecycle {
    prevent_destroy = false
  }
  depends_on = [mongodbatlas_advanced_cluster.global_rs]
}
