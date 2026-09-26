terraform {
  required_version = ">=1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.46.0"
    }
  }

  backend "gcs" {} #I will use a deploy.sh to enter dev or prod for it.
}

provider "google" {
  project               = var.project_id
  billing_project       = var.project_id # for a quota and billing for API calls
  user_project_override = true
}