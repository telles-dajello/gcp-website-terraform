# Approach A: static files in a private Cloud Storage bucket, served by a backend bucket (with Cloud CDN) behind the shared frontend module.
# only the load balancer can read the bucket directly.

locals {
  files = fileset(var.site_dir, "**")

  mime_types = {
    html = "text/html; charset=utf-8"
    css  = "text/css"
    txt  = "text/plain; charset=utf-8"
  }
}

resource "google_storage_bucket" "main" {
  project                     = var.project_id
  name                        = var.bucket_name
  location                    = var.bucket_location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.force_destroy

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 5
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  labels = var.labels
}

# One object per file in site/. A changed file generates a new md5, the object is replaced on the next apply. This is the "auto redeployment" for approach A.
resource "google_storage_bucket_object" "site_file" {
  for_each = local.files

  bucket         = google_storage_bucket.main.name
  name           = each.value
  source         = "${var.site_dir}/${each.value}"
  source_md5hash = filemd5("${var.site_dir}/${each.value}")
  content_type   = try(local.mime_types[lower(regex("[^.]+$", each.value))], "application/octet-stream")

  # All changes show up in up to a minute.
  cache_control = "public, max-age=60"
}

resource "google_compute_backend_bucket" "main" {
  project     = var.project_id
  name        = "${var.name}-backend"
  bucket_name = google_storage_bucket.main.name
  enable_cdn  = var.enable_cdn

  dynamic "cdn_policy" {
    for_each = var.enable_cdn ? [1] : []
    content {
      cache_mode        = "FORCE_CACHE_ALL" # required for private buckets
      default_ttl       = 3600
      client_ttl        = 60
      negative_caching  = true
      serve_while_stale = 86400
    }
  }
}

# Private bucket access: only the load balancer's Google-managed service agent may read objects. Google's docs require objectViewer for it, and only that.
data "google_project" "main" {
  project_id = var.project_id
}

resource "google_storage_bucket_iam_member" "main" {
  bucket = google_storage_bucket.main.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:service-${data.google_project.main.number}@https-lb.iam.gserviceaccount.com"

  depends_on = [google_compute_backend_bucket.main]
}