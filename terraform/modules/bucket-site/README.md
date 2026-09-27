# bucket-site

Approach A: the site's files are stored in a private Cloud Storage bucket, served through a backend bucket with Cloud CDN. Only the load balancer's service agent may read the objects (`roles/storage.objectViewer`).

Each file is an object tied to its md5, so a changed file is re-uploaded on the next apply: that is approach A's automatic redeployment.

## Usage

```hcl
module "bucket_site" {
  source = "../modules/bucket-site"

  project_id      = var.project_id
  name            = "bucket-dev"
  bucket_name     = "my-project-site-dev"
  bucket_location = "US-CENTRAL1"
  site_dir        = "${path.root}/../../site"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.6 |
| google | >= 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| google | >= 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_backend_bucket.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_bucket) | resource |
| [google_storage_bucket.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_object.site_file](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |
| [google_project.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| bucket\_location | Region (cheaper) or multi-region like US. | `string` | n/a | yes |
| bucket\_name | Globally unique bucket name. | `string` | n/a | yes |
| enable\_cdn | Cache the site at Google's edge with Cloud CDN. | `bool` | `true` | no |
| force\_destroy | Allow terraform destroy to delete a non-empty bucket. only true for dev. | `bool` | `false` | no |
| labels | Labels for the bucket. | `map(string)` | `{}` | no |
| name | Name prefix for resources. | `string` | n/a | yes |
| project\_id | Project to deploy into. | `string` | n/a | yes |
| site\_dir | Local folder with the website files. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| backend\_id | Backend bucket ID, for the frontend's URL map. |
| bucket\_name | Name of the bucket that has the site. |
| object\_names | Files uploaded to the bucket. |
| reader\_member | The only identity allowed to read the bucket (the load balancer's service agent). |
<!-- END_TF_DOCS -->
