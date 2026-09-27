# https-frontend

The front door shared by both approaches: a global external Application Load Balancer (`EXTERNAL_MANAGED`) on a reserved static IP, so the endpoint never changes on a redeploy.

- Without `domains`: HTTP on port 80.
- With `domains`: a Google-managed certificate, an SSL policy (TLS 1.2+), HTTPS on port 443 on the same IP, and port 80 redirecting to HTTPS (`tls.tf`).

The caller passes the backend: a backend bucket (approach A) or a backend service (approach B).

## Usage

```hcl
module "bucket_frontend" {
  source = "../modules/https-frontend"

  project_id = var.project_id
  name       = "bucket-dev"
  backend_id = module.bucket_site.backend_id
  domains    = ["www.example.com"] # optional: turns on HTTPS
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
| [google_compute_global_address.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_global_forwarding_rule.http](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_global_forwarding_rule.https](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_managed_ssl_certificate.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_managed_ssl_certificate) | resource |
| [google_compute_ssl_policy.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_ssl_policy) | resource |
| [google_compute_target_http_proxy.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_http_proxy) | resource |
| [google_compute_target_https_proxy.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_https_proxy) | resource |
| [google_compute_url_map.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map) | resource |
| [google_compute_url_map.redirect](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| backend\_id | Backend bucket or backend service that serves the site | `string` | n/a | yes |
| domains | Domains for the managed certificate. Empty list = HTTP only on the IP. | `list(string)` | `[]` | no |
| labels | Labels for the IP address and forwarding rules | `map(string)` | `{}` | no |
| name | Name prefix for resources. | `string` | n/a | yes |
| project\_id | Project to deploy into. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| certificate | Managed certificate ID (null without domains). |
| http\_forwarding\_rule | Port 80 forwarding rule ID. |
| http\_proxy | HTTP proxy ID. |
| https\_forwarding\_rule | Port 443 forwarding rule ID (null without domains). |
| https\_proxy | HTTPS proxy ID (null without domains). |
| ip\_address | Stable public IP. |
| redirect\_url\_map | HTTP-to-HTTPS redirect URL map ID (null without domains). |
| ssl\_policy | SSL policy ID (null without domains). |
| url | Where the site is served. |
| url\_map\_name | URL map name (used for Cloud CDN cache invalidation). |
<!-- END_TF_DOCS -->
