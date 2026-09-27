# Botha approaches to hosting on GCP will use this: a global external Application Load Balancer on a reserved static IP.
# this follows the GCP documentaion to Set up a global external Application Load Balancer with Cloud Storage buckets

# The reserved IP. A separate resource that nothing replaces on redeploy, so the endpoint stays stable
resource "google_compute_global_address" "main" {
  project = var.project_id
  name    = "${var.name}-ip"
  labels  = var.labels
}

resource "google_compute_url_map" "main" {
  project         = var.project_id
  name            = "${var.name}-urlmap"
  default_service = var.backend_id
}

resource "google_compute_target_http_proxy" "main" {
  project = var.project_id
  name    = "${var.name}-http-proxy"
  url_map = local.tls ? google_compute_url_map.redirect[0].id : google_compute_url_map.main.id
}

resource "google_compute_global_forwarding_rule" "http" {
  project               = var.project_id
  name                  = "${var.name}-http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.main.id
  port_range            = "80"
  target                = google_compute_target_http_proxy.main.id
  labels                = var.labels
}