terraform {
  required_version = ">= 1.7" # 1.7+ for mock providers in `terraform test`

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.46.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.46.0"
    }
  }

  # Remote state in the project's own bucket (created by bootstrap). Ddploy.sh passes bucket = "<project>-tfstate", prefix = "live" at init.
  backend "gcs" {}
}

# Locally uses the gcloud login (ADC). In CI it uses the short-lived token from (WIF) Workload Identity Federation.
provider "google" {
  project               = var.project_id
  region                = var.region
  billing_project       = var.project_id
  user_project_override = true
}

provider "google-beta" {
  project               = var.project_id
  region                = var.region
  billing_project       = var.project_id
  user_project_override = true
}