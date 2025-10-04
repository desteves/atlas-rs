output "project_id" {
  value       = local.project_id
  description = "Atlas Project ID in use (existing)"
}

output "cluster_name" {
  value       = mongodbatlas_advanced_cluster.global_rs.name
  description = "Cluster name"
}

output "standard_connection_string" {
  value       = try(data.mongodbatlas_cluster.conn_strings.connection_strings[0].standard_srv, null)
  description = "Base SRV connection string without credentials (available after first apply)."
  sensitive   = true
}

output "demo_effective_mongodb_uri" {
  value       = try(local.effective_mongodb_uri, null)
  description = "MongoDB URI used by the demo (auto-generated from cluster SRV + demo user)."
  sensitive   = true
}
