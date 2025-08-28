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

output "demo_site_urls" {
  value = try({
    us = "https://storage.googleapis.com/${google_storage_bucket.demo_us[0].name}/index.html",
    au = "https://storage.googleapis.com/${google_storage_bucket.demo_au[0].name}/index.html"
  }, null)
  description = "Public GCS static site URLs (null if demo disabled)."
}

output "demo_api_urls" {
  value = try({
    us = google_cloudfunctions2_function.api_us[0].service_config[0].uri,
    au = google_cloudfunctions2_function.api_au[0].service_config[0].uri
  }, null)
  description = "Regional Cloud Functions v2 HTTP endpoints (null if demo disabled)."
}
