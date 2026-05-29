output "cloud_run_url" {
  value       = google_cloud_run_v2_service.app.uri
  description = "Public URL of your Cloud Run service"
}

output "db_connection_name" {
  value       = google_sql_database_instance.postgres.connection_name
  description = "Cloud SQL connection name (project:region:instance)"
}

output "db_public_ip" {
  value       = google_sql_database_instance.postgres.public_ip_address
  description = "Public IP of the Postgres instance"
}

output "gcs_bucket_name" {
  value       = google_storage_bucket.main.name
  description = "Name of the Cloud Storage bucket"
}

output "artifact_registry_url" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.app_name}-repo"
  description = "Docker push URL for your Artifact Registry"
}
