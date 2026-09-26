variable "project_id" {
  description = "Project to deploy into."
  type        = string
}

variable "name" {
  description = "Name prefix for resources."
  type        = string
}

variable "backend_id" {
  description = "Backend bucket or backend service that serves the site"
  type        = string
}

variable "labels" {
  description = "Labels for the IP address and forwarding rules"
  type        = map(string)
  default     = {}
}