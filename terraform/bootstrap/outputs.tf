output "state_bucket" {
  description = "Terraform state bucket for this project"
  value       = google_storage_bucket.main.name
}