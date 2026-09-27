# PROD settings. Same code as dev, different parameters. Project ID comes from PROJECT=...
region = "us-east1" # different from dev to show region per-project

# Approach A
enable_bucket_site = true
bucket_location    = "US" # US multi-region
enable_cdn         = true

# Approach B
enable_vm_site  = true
machine_type    = "e2-small"
instance_count  = 2 # two zones: survives a zone outage
log_sample_rate = 0.5