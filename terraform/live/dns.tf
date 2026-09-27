# DNS: A records in the Cloud DNS zone created by bootstrap (optional). Every domain in site domains gets an A record pointing to the stable IP of the approach
# The managed certificate then validates on its own.
data "google_dns_managed_zone" "main" {
  count   = var.manage_dns ? 1 : 0
  project = var.project_id
  name    = "site"
}

# Which domain points to which IP: approach A's domains get A's IP, approach B's domains get B's IP.
# If an approach is switched off, its domains are left out (its load balancer doesn't exist).
# If manage_dns is false, the list is empty and no DNS records are created.
# The resource below creates one DNS A record for each domain in this list.
locals {
  dns_records = var.manage_dns ? merge(
    var.enable_bucket_site ? { for domain in var.bucket_site_domains : domain => module.bucket_frontend[0].ip_address } : {},
    var.enable_vm_site ? { for domain in var.vm_site_domains : domain => module.vm_frontend[0].ip_address } : {},
  ) : {}
}

resource "google_dns_record_set" "main" {
  for_each     = local.dns_records
  project      = var.project_id
  managed_zone = data.google_dns_managed_zone.main[0].name
  name         = "${each.key}."
  type         = "A"
  ttl          = 300
  rrdatas      = [each.value]
}