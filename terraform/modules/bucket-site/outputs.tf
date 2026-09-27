output "backend_id" {
  description = "Backend bucket ID, for the frontend's URL map."
  value       = google_compute_backend_bucket.main.id
}

output "bucket_name" {
  description = "Name of the bucket that has the site."
  value       = google_storage_bucket.main.name
}

output "object_names" {
  description = "Files uploaded to the bucket."
  value       = sort([for item in google_storage_bucket_object.site_file : item.name])
}

output "reader_member" {
  description = "The only identity allowed to read the bucket (the load balancer's service agent)."
  value       = google_storage_bucket_iam_member.main.member
}