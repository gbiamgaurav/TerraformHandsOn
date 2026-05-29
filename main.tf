# --- ENABLE REQUIRED APIs ---
resource "google_project_service" "services" {
  for_each = toset([
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
  ])
  service            = each.key
  disable_on_destroy = false
}


# --- CLOUD STORAGE BUCKETS ---
resource "google_storage_bucket" "main" {
  name                        = "${var.project_id}-${var.app_name}-storage"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
}


# --- ARTIFACT REGISTRY (Docker image repo) ---
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "${var.app_name}-repo"
  format        = "DOCKER"
  depends_on    = [google_project_service.services]
}
