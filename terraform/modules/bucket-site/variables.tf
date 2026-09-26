variable "project_id" {
  description = "Project to deploy into."
  type        = string
}

variable "name" {
  description = "Name prefix for resources."
  type        = string
}

variable "bucket_name" {
  description = "Globally unique bucket name."
  type        = string
}

variable "bucket_location" {
  description = "Region (cheaper) or multi-region like US."
  type        = string
}

variable "site_dir" {
  description = "Local folder with the website files."
  type        = string
}

variable "enable_cdn" {
  description = "Cache the site at Google's edge with Cloud CDN."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete a non-empty bucket. only true for dev."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels for the bucket."
  type        = map(string)
  default     = {}
}