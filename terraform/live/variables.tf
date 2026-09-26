variable "project_id" {
  description = "Google Cloud project for this environment (PROJECT=... in deploy.sh)."
  type        = string
}

variable "environment" {
  description = "Environment name: dev or prod (ENV=... in deploy.sh)."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be \"dev\" or \"prod\"."
  }
}

variable "region" {
  description = "Region for regional resources (VMs, subnet)."
  type        = string
}

# Approach A - GCS (private bucket) + Cloud Load Balancing + Cloud CDN
variable "enable_bucket_site" {
  description = "Deploy approach A (Cloud Storage + CDN)."
  type        = bool
  default     = true
}

variable "bucket_location" {
  description = "Bucket location: a region (cheaper) or US."
  type        = string
}

variable "enable_cdn" {
  description = "Enable Cloud CDN for approach A."
  type        = bool
  default     = true
}