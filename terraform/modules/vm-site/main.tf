# Approach B: nginx on a regional Managed Instance Group (MIG) of small VMs, behind the shared frontend module.
# Redeploy flow: 
# the HTML is in the instance template's metadata. --- Changed HTML --- new template -- the MIG does a rolling replacement -- same load balancer IP.

locals {
  network_tag = "${var.name}-web"
}

# Instance template
resource "google_compute_instance_template" "main" {
  project      = var.project_id
  name_prefix  = "${var.name}-"
  machine_type = var.machine_type
  region       = var.region
  tags         = [local.network_tag]

  disk {
    source_image = var.source_image
    disk_type    = var.disk_type
    disk_size_gb = 10
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.main.id
  }

  service_account {
    email  = var.vm_service_account_email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin = "TRUE"
    startup-script = file("${path.module}/files/startup.sh")
    # The site itself, read by startup.sh.
    site-index-html = file("${var.site_dir}/index.html")
    site-404-html   = file("${var.site_dir}/404.html")
  }

  labels = var.labels

  lifecycle {
    create_before_destroy = true # always points at a live template
  }
}

# Health check + regional MIG
resource "google_compute_health_check" "main" {
  project             = var.project_id
  name                = "${var.name}-hc"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

# google-beta: `update_policy.min_ready_sec` is a beta field. It makes the rolling update wait until all new VM has been serving for X seconds before it continues,
# which makes the redeploy safe.
resource "google_compute_region_instance_group_manager" "main" {
  provider = google-beta

  project            = var.project_id
  name               = "${var.name}-mig"
  region             = var.region
  base_instance_name = "${var.name}-web"
  target_size        = var.instance_count

  version {
    instance_template = google_compute_instance_template.main.id
  }

  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.main.id
    initial_delay_sec = 120 # time for boot + apt install
  }

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 3 # regional MIG: 0 or >= its number of zones (3 by default), so each zone can get a new VM first
    max_unavailable_fixed = 0 # never drop below capacity during a redeploy
    min_ready_sec         = 30
  }
}

resource "google_compute_backend_service" "main" {
  project               = var.project_id
  name                  = "${var.name}-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.main.id]
  enable_cdn            = false # keeps approach B "dynamic-ready"

  backend {
    group           = google_compute_region_instance_group_manager.main.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  log_config {
    enable      = true
    sample_rate = var.log_sample_rate
  }
}