# Cloud DNS zone for your domain
# Lives in bootstrap, not in live, `helpers/deploy.sh destroy` must never delete the zone, or its name servers would change and the registrar would point at nothing.
resource "google_dns_managed_zone" "main" {
  count       = var.dns_domain == "" ? 0 : 1
  project     = var.project_id
  name        = "site"
  dns_name    = "${var.dns_domain}."
  description = "Public zone for the website (${var.environment})"

  lifecycle {
    prevent_destroy = true # DOMAIN is optional but once created, every bootstrap re-run needs the same DOMAIN=...
  }

  depends_on = [google_project_service.api]
}

resource "google_dns_managed_zone_iam_member" "main" {
  count        = var.dns_domain == "" ? 0 : 1
  project      = var.project_id
  managed_zone = google_dns_managed_zone.main[0].name
  role         = "roles/dns.admin"
  member       = "serviceAccount:${google_service_account.deployer.email}"
}