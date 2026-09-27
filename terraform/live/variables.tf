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

# Approach B - Compute Engine regional MIG (nginx) + Cloud Load Balancing + Cloud NAT
variable "enable_vm_site" {
  description = "Deploy approach B (managed instance group)."
  type        = bool
  default     = true
}

variable "machine_type" {
  description = "VM machine type for approach B."
  type        = string
  default     = "e2-micro"
}

variable "instance_count" {
  description = "Number of VMs for approach B."
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "instance_count must be between 1 and 10."
  }
}

variable "log_sample_rate" {
  description = "Fraction of LB requests to log for approach B."
  type        = number
  default     = 1.0
}

# Domains and DNS
variable "bucket_site_domains" {
  description = "Domains for approach A's certificate. Empty = HTTP on the IP only."
  type        = list(string)
  default     = []
}

variable "vm_site_domains" {
  description = "Domains for approach B's certificate. Empty = HTTP on the IP only."
  type        = list(string)
  default     = []
}

variable "manage_dns" {
  description = "Create A records for the site domains in the Cloud DNS zone made by bootstrap (DOMAIN=...)."
  type        = bool
  default     = false
}