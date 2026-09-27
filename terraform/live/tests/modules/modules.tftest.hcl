# Tests run against MOCK providers:
# no Google Cloud account, no credentials, no cost. Run with: bash helpers/deploy.sh test
#
# `command = plan` checks what the config asks for.
# `command = apply` (mocked) lets two runs be compared, e.g. "the IP didn't change".

mock_provider "google" {}
mock_provider "google-beta" {}

# https-frontend: stable endpoint + TLS

run "frontend_first_deploy" {
  command = apply

  module {
    source = "../modules/https-frontend"
  }

  variables {
    project_id = "test-project"
    name       = "test"
    backend_id = "projects/test-project/global/backendBuckets/backend-v1"
    domains    = []
  }

  assert {
    condition     = length(google_compute_managed_ssl_certificate.main) == 0
    error_message = "No domains should mean no certificate (plain HTTP in dev)."
  }

  assert {
    condition     = google_compute_global_forwarding_rule.http.port_range == "80"
    error_message = "Without TLS the site must be served on port 80."
  }
}

run "frontend_redeploy_keeps_the_same_ip" {
  command = apply

  module {
    source = "../modules/https-frontend"
  }

  # Same frontend, different backend: what happens on a redeploy.
  variables {
    project_id = "test-project"
    name       = "test"
    backend_id = "projects/test-project/global/backendBuckets/backend-v2"
    domains    = []
  }

  assert {
    condition     = output.ip_address == run.frontend_first_deploy.ip_address
    error_message = "Stable endpoint: the IP address must not change on a redeploy."
  }
}

run "frontend_with_domain_turns_on_tls" {
  command = plan

  module {
    source = "../modules/https-frontend"
  }

  variables {
    project_id = "test-project"
    name       = "tls"
    backend_id = "projects/test-project/global/backendBuckets/backend"
    domains    = ["www.example.com"]
  }

  assert {
    condition     = length(google_compute_managed_ssl_certificate.main) == 1
    error_message = "A domain should create a managed certificate."
  }

  assert {
    condition     = google_compute_global_forwarding_rule.https[0].port_range == "443"
    error_message = "With TLS there must be an HTTPS forwarding rule on 443."
  }

  assert {
    condition     = google_compute_ssl_policy.main[0].min_tls_version == "TLS_1_2"
    error_message = "TLS older than 1.2 must be refused."
  }

  assert {
    condition     = google_compute_url_map.redirect[0].default_url_redirect[0].https_redirect == true
    error_message = "With TLS, HTTP must redirect to HTTPS."
  }
}

# bucket-site (approach A)

run "bucket_site_uploads_every_file_safely" {
  command = plan

  module {
    source = "../modules/bucket-site"
  }

  variables {
    project_id      = "test-project"
    name            = "bucket-test"
    bucket_name     = "test-project-site-test"
    bucket_location = "US-CENTRAL1"
    site_dir        = "../../site"
  }

  assert {
    condition     = length(google_storage_bucket_object.site_file) == length(fileset("../../site", "**"))
    error_message = "Every file in site/ must be uploaded."
  }

  assert {
    condition     = google_storage_bucket_object.site_file["index.html"].source_md5hash == filemd5("../../site/index.html")
    error_message = "Auto-redeploy: the object must be tied to the file's content (md5)."
  }

  assert {
    condition     = google_storage_bucket_object.site_file["index.html"].content_type == "text/html; charset=utf-8"
    error_message = "HTML must be served as text/html."
  }

  assert {
    condition     = google_storage_bucket_object.site_file["index.html"].cache_control == "public, max-age=60"
    error_message = "HTML should have a short cache so changes show up quickly."
  }

  assert {
    condition     = google_storage_bucket.main.versioning[0].enabled
    error_message = "Versioning must be on so a bad deploy can be rolled back."
  }

  assert {
    condition     = google_storage_bucket.main.public_access_prevention == "enforced"
    error_message = "The bucket must be private: nobody on the internet may read it directly."
  }

  assert {
    condition     = endswith(google_storage_bucket_iam_member.main.member, "@https-lb.iam.gserviceaccount.com") && google_storage_bucket_iam_member.main.role == "roles/storage.objectViewer"
    error_message = "Only the load balancer's service agent may read the bucket, with objectViewer."
  }

  assert {
    condition     = google_storage_bucket.main.uniform_bucket_level_access
    error_message = "Bucket permissions must be managed at bucket level only (no per-object ACLs)."
  }
}

# vm-site (approach B)

run "vm_site_v1" {
  command = apply

  module {
    source = "../modules/vm-site"
  }

  variables {
    project_id               = "test-project"
    name                     = "vm-test"
    region                   = "us-central1"
    site_dir                 = "../../site"
    machine_type             = "e2-micro"
    instance_count           = 1
    vm_service_account_email = "web-vm@test-project.iam.gserviceaccount.com"
  }

  assert {
    condition     = google_compute_instance_template.main.machine_type == "e2-micro"
    error_message = "The machine type must come from the per-environment setting."
  }

  assert {
    condition     = length(google_compute_instance_template.main.network_interface[0].access_config) == 0
    error_message = "VMs must not have public IP addresses."
  }

  assert {
    condition     = toset(google_compute_firewall.main.source_ranges) == toset(["35.191.0.0/16", "130.211.0.0/22"])
    error_message = "Only Google's load balancer and health checks may reach the VMs."
  }

  assert {
    condition     = google_compute_region_instance_group_manager.main.update_policy[0].max_unavailable_fixed == 0
    error_message = "Zero downtime: a redeploy must never take VMs away before new ones are ready."
  }

  assert {
    condition     = google_compute_region_instance_group_manager.main.update_policy[0].min_ready_sec > 0
    error_message = "New VMs must prove healthy for a while before the rollout continues (google-beta field)."
  }

  assert {
    condition     = google_compute_instance_template.main.disk[0].disk_type == "pd-standard"
    error_message = "A standard disk keeps the dev e2-micro inside the Free Tier."
  }
}

run "vm_site_html_change_rolls_out_new_template" {
  command = apply

  module {
    source = "../modules/vm-site"
  }

  # Same settings, different HTML (tests/fixtures/site-v2).
  variables {
    project_id               = "test-project"
    name                     = "vm-test"
    region                   = "us-central1"
    site_dir                 = "tests/fixtures/site-v2"
    machine_type             = "e2-micro"
    instance_count           = 1
    vm_service_account_email = "web-vm@test-project.iam.gserviceaccount.com"
  }

  # Instance templates can't be edited once created, so the real provider replaces the template when its HTML changes, and the MIG rolls out new VMs. 
  # A mock provider doesn't know which changes force a replacement, so the test checks what this code controls: the new HTML is inside the template.
  assert {
    condition     = google_compute_instance_template.main.metadata["site-index-html"] == file("tests/fixtures/site-v2/index.html")
    error_message = "Auto-redeploy: the new HTML must be inside the instance template (templates can't be edited, so a new one is created and the MIG rolls it out)."
  }

  assert {
    condition     = google_compute_instance_template.main.metadata["site-index-html"] != file("../../site/index.html")
    error_message = "The template's HTML must differ from the first deploy's, or this test proves nothing."
  }

  assert {
    condition     = output.backend_id == run.vm_site_v1.backend_id
    error_message = "The backend service must stay the same (only the VMs are replaced)."
  }
}
