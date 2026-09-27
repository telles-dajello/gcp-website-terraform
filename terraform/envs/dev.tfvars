# DEV settings. The project ID comes from the command line (PROJECT=...).
region = "us-central1"

# Approach A
enable_bucket_site = true
bucket_location    = "US-CENTRAL1"
enable_cdn         = true

# Approach B
enable_vm_site  = true
machine_type    = "e2-micro"
instance_count  = 1
log_sample_rate = 1.0

# No domain and no TLS in dev: served on http://<ip>
bucket_site_domains = []
vm_site_domains     = []
manage_dns          = false