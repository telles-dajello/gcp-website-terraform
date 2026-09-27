# Guardrails on the per-environment settings (envs/dev.tfvars, envs/prod.tfvars). deploy.sh test runs this once with each environment's settings file.

mock_provider "google" {}
mock_provider "google-beta" {}

run "settings_are_valid" {
  command = plan

  assert {
    condition     = startswith(var.region, "us-")
    error_message = "US-only audience: the region must be a US region."
  }

  assert {
    condition     = startswith(upper(var.bucket_location), "US")
    error_message = "US-only audience: the bucket must be in a US location."
  }

  assert {
    condition     = var.environment != "prod" || var.instance_count >= 2
    error_message = "Prod needs at least 2 VMs, so it survives the loss of one zone."
  }

  assert {
    condition     = var.environment != "dev" || var.machine_type == "e2-micro"
    error_message = "Dev should use e2-micro to stay inside the Free Tier."
  }

  assert {
    condition     = !var.manage_dns || length(concat(var.bucket_site_domains, var.vm_site_domains)) > 0
    error_message = "manage_dns is on but no domains are set: nothing to point at the load balancers."
  }

  assert {
    condition     = length(output.dns_records) == (var.manage_dns ? length(distinct(concat(var.bucket_site_domains, var.vm_site_domains))) : 0)
    error_message = "Every domain must get exactly one A record when manage_dns is on (and none when it's off)."
  }

  assert {
    condition     = var.enable_bucket_site || var.enable_vm_site
    error_message = "At least one approach must be enabled."
  }
}