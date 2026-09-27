# HTTPS for the shared frontend. Every resource here has count = 0 when `domains` is empty, so an environment without a domain stays on plain HTTP.

locals {
  tls = length(var.domains) > 0
}

# The Google-managed certificate for the domains. It turns ACTIVE only after the domains' DNS A records point at the reserved IP (up to 60 minutes).
resource "google_compute_managed_ssl_certificate" "main" {
  count   = local.tls ? 1 : 0
  project = var.project_id
  name    = "${var.name}-cert"

  managed {
    domains = var.domains
  }
}

resource "google_compute_ssl_policy" "main" {
  count           = local.tls ? 1 : 0
  project         = var.project_id
  name            = "${var.name}-ssl-policy"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

resource "google_compute_target_https_proxy" "main" {
  count            = local.tls ? 1 : 0
  project          = var.project_id
  name             = "${var.name}-https-proxy"
  url_map          = google_compute_url_map.main.id
  ssl_certificates = [google_compute_managed_ssl_certificate.main[0].id]
  ssl_policy       = google_compute_ssl_policy.main[0].id
}

# Port 443 on the same reserved IP.
resource "google_compute_global_forwarding_rule" "https" {
  count                 = local.tls ? 1 : 0
  project               = var.project_id
  name                  = "${var.name}-https"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.main.id
  port_range            = "443"
  target                = google_compute_target_https_proxy.main[0].id
  labels                = var.labels
}

resource "google_compute_url_map" "redirect" {
  count   = local.tls ? 1 : 0
  project = var.project_id
  name    = "${var.name}-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}