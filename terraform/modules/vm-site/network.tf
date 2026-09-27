# Approach B has a private network in order for the VMs to have no public IP. use Cloud NAT for outbound connection. Accepts traffic only from Load Balancer.

locals {
  # Ranges used by Google Front Ends and health checks for external Application LBs.
  lb_source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}

resource "google_compute_network" "main" {
  project                 = var.project_id
  name                    = "${var.name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  project                  = var.project_id
  name                     = "${var.name}-subnet"
  region                   = var.region
  network                  = google_compute_network.main.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true
}

# Outbound internet only for installing nginx at boot.
resource "google_compute_router" "main" {
  project = var.project_id
  name    = "${var.name}-router"
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "main" {
  project                            = var.project_id
  name                               = "${var.name}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Only the load balancer and its health checks can reach the VMs.
resource "google_compute_firewall" "main" {
  project       = var.project_id
  name          = "${var.name}-allow-lb"
  network       = google_compute_network.main.id
  direction     = "INGRESS"
  source_ranges = local.lb_source_ranges
  target_tags   = [local.network_tag]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}