# Root module: the same code is deployed to dev and prod. 
# Only the inputs differ: project_id + environment (from deploy.sh), and the settings in terraform/envs/<env>.tfvars.

locals {
  site_dir = "${path.root}/../../site"

    # Created by bootstrap (deterministic name).
  vm_service_account_email = "web-vm@${var.project_id}.iam.gserviceaccount.com"

  labels = {
    env        = var.environment
    managed-by = "terraform"
  }
}

# Approach A: Cloud Storage + Cloud CDN
module "bucket_site" {
  source = "../modules/bucket-site"
  count  = var.enable_bucket_site ? 1 : 0

  project_id      = var.project_id
  name            = "bucket-${var.environment}"
  bucket_name     = "${var.project_id}-site-${var.environment}"
  bucket_location = var.bucket_location
  site_dir        = local.site_dir
  enable_cdn      = var.enable_cdn
  force_destroy   = var.environment != "prod"
  labels          = local.labels
}

module "bucket_frontend" {
  source = "../modules/https-frontend"
  count  = var.enable_bucket_site ? 1 : 0

  project_id = var.project_id
  name       = "bucket-${var.environment}"
  backend_id = module.bucket_site[0].backend_id
  labels     = local.labels
}

# Approach B: Compute Engine managed instance group
module "vm_site" {
  source = "../modules/vm-site"
  count  = var.enable_vm_site ? 1 : 0

  providers = {
    google      = google
    google-beta = google-beta
  }

  project_id               = var.project_id
  name                     = "vm-${var.environment}"
  region                   = var.region
  site_dir                 = local.site_dir
  machine_type             = var.machine_type
  instance_count           = var.instance_count
  vm_service_account_email = local.vm_service_account_email
  log_sample_rate          = var.log_sample_rate
  labels                   = local.labels
}

module "vm_frontend" {
  source = "../modules/https-frontend"
  count  = var.enable_vm_site ? 1 : 0

  project_id = var.project_id
  name       = "vm-${var.environment}"
  backend_id = module.vm_site[0].backend_id
  labels     = local.labels
}