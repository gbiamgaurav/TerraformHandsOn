# --- CLOUD SQL (POSTGRES) ---
resource "google_sql_database_instance" "postgres" {
  name             = "${var.app_name}-db"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled = true
    }
  }

  deletion_protection = false
  depends_on          = [google_project_service.services]
}

resource "google_sql_database" "app_db" {
  name     = "${var.app_name}_db"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "app_user" {
  name     = "${var.app_name}_user"
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
}
