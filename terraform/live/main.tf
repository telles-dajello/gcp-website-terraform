# Root module: the same code is deployed to dev and prod. 
# Only the inputs differ: project_id + environment (from deploy.sh), and the settings in terraform/envs/<env>.tfvars.

locals {
  site_dir = "${path.root}/../../site"

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