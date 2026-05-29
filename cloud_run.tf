# --- CLOUD RUN SERVICE ---
resource "google_cloud_run_v2_service" "app" {
  name     = "${var.app_name}-service"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.postgres.connection_name]
      }
    }

    containers {
      # Replace this image with your own after pushing to Artifact Registry
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      env {
        name  = "DB_CONNECTION_NAME"
        value = google_sql_database_instance.postgres.connection_name
      }
      env {
        name  = "DB_USER"
        value = google_sql_user.app_user.name
      }
      env {
        name  = "DB_NAME"
        value = google_sql_database.app_db.name
      }
      env {
        name  = "GCS_BUCKET"
        value = google_storage_bucket.main.name
      }
    }
  }

  depends_on = [google_project_service.services]
}

# Allow anyone to call this Cloud Run service (public access)
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  name     = google_cloud_run_v2_service.app.name
  location = google_cloud_run_v2_service.app.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
