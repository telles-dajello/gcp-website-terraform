variable "project_id" {
  description = "Google Cloud project to bootstrap (retrieved from the PROJECT= at the CLI)"
  type        = string
}

variable "environment" {
  description = "dev or prod (retrieved from the ENV= at the CLI)."
  type        = string
}