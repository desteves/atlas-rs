output "cluster_name" {
  value       = mongodbatlas_advanced_cluster.global_rs.name
  description = "Cluster name"
}

output "standard_connection_string" {
  value       = try(data.mongodbatlas_advanced_cluster.conn_strings.connection_strings[0].standard_srv, null)
  description = "Base SRV connection string without credentials"
  sensitive   = false
}
