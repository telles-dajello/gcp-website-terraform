variable "project_id" {
  description = "Project to deploy into."
  type        = string
}

variable "name" {
  description = "Name prefix for resources, like \"vm-dev\"."
  type        = string
}

variable "region" {
  description = "Region for the VMs (spread across its zones)."
  type        = string
}

variable "site_dir" {
  description = "Local folder with index.html and 404.html."
  type        = string
}

variable "machine_type" {
  description = "VM machine type, e.g. e2-micro (dev) or e2-small (prod)."
  type        = string
}

variable "instance_count" {
  description = "Number of VMs. 2+ gives zone redundancy."
  type        = number
  default     = 1
}

variable "source_image" {
  description = "Boot image (family link)."
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "disk_type" {
  description = "Boot disk type. pd-standard keeps an e2-micro inside the Free Tier."
  type        = string
  default     = "pd-standard"
}

variable "subnet_cidr" {
  description = "CIDR of the web subnet."
  type        = string
  default     = "10.10.0.0/24"
}

variable "vm_service_account_email" {
  description = "Runtime service account for the VMs (created in bootstrap)."
  type        = string
}

variable "log_sample_rate" {
  description = "Fraction of LB requests to log (0.0 to 1.0)."
  type        = number
  default     = 1.0
}

variable "labels" {
  description = "Labels for the VMs."
  type        = map(string)
  default     = {}
}