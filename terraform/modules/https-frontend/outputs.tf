output "ip_address" {
  description = "Stable public IP."
  value       = google_compute_global_address.main.address
}

output "url" {
  description = "Where the site is served."
  value       = local.tls ? "https://${google_compute_managed_ssl_certificate.main[0].managed[0].domains[0]}" : "http://${google_compute_global_address.main.address}"
}

output "url_map_name" {
  description = "URL map name (used for Cloud CDN cache invalidation)."
  value       = google_compute_url_map.main.name
}

output "http_proxy" {
  description = "HTTP proxy ID."
  value       = google_compute_target_http_proxy.main.id
}

output "http_forwarding_rule" {
  description = "Port 80 forwarding rule ID."
  value       = google_compute_global_forwarding_rule.http.id
}

output "certificate" {
  description = "Managed certificate ID (null without domains)."
  value       = one(google_compute_managed_ssl_certificate.main[*].id)
}

output "ssl_policy" {
  description = "SSL policy ID (null without domains)."
  value       = one(google_compute_ssl_policy.main[*].id)
}

output "https_proxy" {
  description = "HTTPS proxy ID (null without domains)."
  value       = one(google_compute_target_https_proxy.main[*].id)
}

output "https_forwarding_rule" {
  description = "Port 443 forwarding rule ID (null without domains)."
  value       = one(google_compute_global_forwarding_rule.https[*].id)
}

output "redirect_url_map" {
  description = "HTTP-to-HTTPS redirect URL map ID (null without domains)."
  value       = one(google_compute_url_map.redirect[*].id)
}