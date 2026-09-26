output "bucket_site_url" {
  description = "Approach A URL."
  value       = one(module.bucket_frontend[*].url)
}

output "bucket_site_ip" {
  description = "Approach A stable IP."
  value       = one(module.bucket_frontend[*].ip_address)
}

output "bucket_site_url_map" {
  description = "Approach A URL map (for CDN cache invalidation)."
  value       = try(module.bucket_frontend[0].url_map_name, "")
}

output "vm_site_url" {
  description = "Approach B URL."
  value       = one(module.vm_frontend[*].url)
}

output "vm_site_ip" {
  description = "Approach B stable IP."
  value       = one(module.vm_frontend[*].ip_address)
}