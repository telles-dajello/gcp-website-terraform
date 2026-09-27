variable "project_id" {
  description = "Google Cloud project to bootstrap (retrieved from the PROJECT= at the CLI)"
  type        = string
}

variable "environment" {
  description = "dev or prod (retrieved from the ENV= at the CLI)."
  type        = string
}

variable "github_repository" {
  description = "owner/repo allowed to deploy (it's the GITHUB_REPO=...)."
  type        = string
}

variable "github_repository_id" {
  description = "GitHub repo ID allowed to deploy (deploy.sh looks for it from GITHUB_REPO)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_id))
    error_message = "github_repository_id must be the numeric repository ID, not owner/repo."
  }
}

variable "dns_domain" {
  description = "your-domain.com (from DOMAIN=...). Empty = no Cloud DNS zone."
  type        = string
  default     = ""

  validation {
    condition     = var.dns_domain == "" || can(regex("^[a-z0-9-]+(\\.[a-z0-9-]+)+$", var.dns_domain))
    error_message = "dns_domain must be a bare domain like your-domain.com (lowercase, no https://, no trailing dot)."
  }
}