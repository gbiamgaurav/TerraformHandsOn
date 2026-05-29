variable "project_id" {
  description = "Your GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "us-central1"
}

variable "app_name" {
  description = "Base name used to prefix all resources"
  type        = string
  default     = "myapp"
}

variable "db_password" {
  description = "Password for the Postgres database user"
  type        = string
  sensitive   = true
}
