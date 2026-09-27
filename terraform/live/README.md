# live

The root configuration deployed to both projects. It assembles the modules (approach A: `bucket-site` + `https-frontend`; approach B: `vm-site` + `https-frontend`) and, in prod, the DNS A records (`dns.tf`). Remote state: `gs://<project>-tfstate`, prefix `live`.

Run it through `helpers/deploy.sh`, which passes `project_id` and `environment` and picks `envs/<env>.tfvars`.

## Usage

```bash
PROJECT=my-project ENV=dev bash helpers/deploy.sh plan
PROJECT=my-project ENV=dev bash helpers/deploy.sh apply
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.7 |
| google | ~> 7.46.0 |
| google-beta | ~> 7.46.0 |

## Providers

| Name | Version |
| ---- | ------- |
| google | 7.46.1 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| bucket\_frontend | ../modules/https-frontend | n/a |
| bucket\_site | ../modules/bucket-site | n/a |
| vm\_frontend | ../modules/https-frontend | n/a |
| vm\_site | ../modules/vm-site | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [google_dns_record_set.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_dns_managed_zone.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/dns_managed_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| bucket\_location | Bucket location: a region (cheaper) or US. | `string` | n/a | yes |
| bucket\_site\_domains | Domains for approach A's certificate. Empty = HTTP on the IP only. | `list(string)` | `[]` | no |
| enable\_bucket\_site | Deploy approach A (Cloud Storage + CDN). | `bool` | `true` | no |
| enable\_cdn | Enable Cloud CDN for approach A. | `bool` | `true` | no |
| enable\_vm\_site | Deploy approach B (managed instance group). | `bool` | `true` | no |
| environment | Environment name: dev or prod (ENV=... in deploy.sh). | `string` | n/a | yes |
| instance\_count | Number of VMs for approach B. | `number` | `1` | no |
| log\_sample\_rate | Fraction of LB requests to log for approach B. | `number` | `1` | no |
| machine\_type | VM machine type for approach B. | `string` | `"e2-micro"` | no |
| manage\_dns | Create A records for the site domains in the Cloud DNS zone made by bootstrap (DOMAIN=...). | `bool` | `false` | no |
| project\_id | Google Cloud project for this environment (PROJECT=... in deploy.sh). | `string` | n/a | yes |
| region | Region for regional resources (VMs, subnet). | `string` | n/a | yes |
| vm\_site\_domains | Domains for approach B's certificate. Empty = HTTP on the IP only. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| bucket\_site\_ip | Approach A stable IP. |
| bucket\_site\_url | Approach A URL. |
| bucket\_site\_url\_map | Approach A URL map (for CDN cache invalidation). |
| dns\_records | A records managed by Terraform (domain - IP). |
| vm\_site\_ip | Approach B stable IP. |
| vm\_site\_url | Approach B URL. |
<!-- END_TF_DOCS -->
