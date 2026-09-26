# All IAM lives in bootstrap, run the Owner, this way the CI doesn't deal with giving permissions

locals {
  deployer_roles = [
    "roles/compute.loadBalancerAdmin",
    "roles/compute.instanceAdmin.v1",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/storage.admin",
    "roles/browser",
    "roles/serviceusage.serviceUsageConsumer",
  ]
}

# Service accounts
resource "google_service_account" "deployer" {
  project      = var.project_id
  account_id   = "gh-deployer"
  display_name = "GitHub Actions deployer (${var.environment})"
  depends_on   = [google_project_service.api]
}

resource "google_project_iam_member" "deployer" {
  for_each = toset(local.deployer_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_service_account" "vm" {
  project      = var.project_id
  account_id   = "web-vm"
  display_name = "Web VM (${var.environment})"
  depends_on   = [google_project_service.api]
}

# The VMs don't need much other than write logs.
resource "google_project_iam_member" "vm_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

resource "google_service_account_iam_member" "deployer_uses_vm_service_account" {
  service_account_id = google_service_account.vm.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployer.email}"
}