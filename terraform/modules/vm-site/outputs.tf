output "backend_id" {
  description = "Backend service ID, for the frontend's URL map."
  value       = google_compute_backend_service.main.id
}

output "instance_group" {
  description = "The regional managed instance group (MIG)."
  value       = google_compute_region_instance_group_manager.main.instance_group
}

output "instance_template" {
  description = "Current instance template (changes on every HTML change)."
  value       = google_compute_instance_template.main.id
}

output "network_id" {
  description = "VPC network ID."
  value       = google_compute_network.main.id
}

output "subnetwork_id" {
  description = "Subnet the VMs run in."
  value       = google_compute_subnetwork.main.id
}

output "router_name" {
  description = "Cloud Router used by Cloud NAT."
  value       = google_compute_router.main.name
}

output "nat_name" {
  description = "Cloud NAT gateway (outbound only)."
  value       = google_compute_router_nat.main.name
}

output "firewall_name" {
  description = "Firewall rule that admits only Google's load balancer and health checks."
  value       = google_compute_firewall.main.name
}

output "health_check_id" {
  description = "Health check used by the load balancer and for autohealing."
  value       = google_compute_health_check.main.id
}