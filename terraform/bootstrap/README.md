# bootstrap

It should be run once per project, by a person with Owner rights. It creates what is needed but cannot be create by itself: the APIs, the state bucket (`main.tf`), the deployer and VM service accounts and their roles (`iam.tf`), Workload Identity Federation for GitHub Actions (`wif.tf`) and, if done with a domain, the Cloud DNS zone (`dns.tf`).

The first run keeps its state locally, then `helpers/deploy.sh` moves it to the bucket just created.

## Usage

```bash
PROJECT=my-project ENV=dev GITHUB_REPO=owner/repo bash helpers/deploy.sh bootstrap
PROJECT=my-prod ENV=prod GITHUB_REPO=owner/repo DOMAIN=example.com bash helpers/deploy.sh bootstrap
```

Files: `dns.tf`, `iam.tf`, `main.tf`, `outputs.tf`, `variables.tf`, `versions.tf`, `wif.tf`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >=1.6 |
| google | ~> 7.46.0 |

## Providers

| Name | Version |
| ---- | ------- |
| google | 7.46.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_dns_managed_zone.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone) | resource |
| [google_dns_managed_zone_iam_member.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone_iam_member) | resource |
| [google_iam_workload_identity_pool.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_project_iam_member.deployer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.vm_log_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.deployer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.deployer_uses_vm_service_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_service_account_iam_member.wif](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_storage_bucket.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| dns\_domain | your-domain.com (from DOMAIN=...). Empty = no Cloud DNS zone. | `string` | `""` | no |
| environment | dev or prod (retrieved from the ENV= at the CLI). | `string` | n/a | yes |
| github\_repository | owner/repo allowed to deploy (it's the GITHUB\_REPO=...). | `string` | n/a | yes |
| github\_repository\_id | GitHub repo ID allowed to deploy (deploy.sh looks for it from GITHUB\_REPO). | `string` | n/a | yes |
| project\_id | Google Cloud project to bootstrap (retrieved from the PROJECT= at the CLI) | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| deployer\_service\_account | GitHub environment variable GCP\_DEPLOYER\_SA. |
| dns\_name\_servers | Type these into your domain registrar as custom name servers (once). |
| state\_bucket | Terraform state bucket for this project |
| vm\_service\_account | Identity used by VMs in approach B. |
| workload\_identity\_provider | GitHub environment variable GCP\_WIF\_PROVIDER. |
<!-- END_TF_DOCS -->
