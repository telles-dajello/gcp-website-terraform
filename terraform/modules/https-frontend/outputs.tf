output "ip_address" {
  description = "Stable public IP."
  value       = google_compute_global_address.main.address
}

output "url" {
  description = "Where the site is served."
  value       = "http://${google_compute_global_address.main.address}"
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