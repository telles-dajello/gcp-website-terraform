output "state_bucket" {
  description = "Terraform state bucket for this project"
  value       = google_storage_bucket.main.name
}

output "deployer_service_account" {
  description = "GitHub environment variable GCP_DEPLOYER_SA."
  value       = google_service_account.deployer.email
}

output "vm_service_account" {
  description = "Identity used by VMs in approach B."
  value       = google_service_account.vm.email
}