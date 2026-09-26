# vm-site

Approach B: nginx on a regional managed instance group of small VMs with no public IPs (`network.tf`: VPC, subnet, Cloud NAT for outbound only, a firewall that admits only Google's load balancer).

The HTML goes in the instance template's metadata and `files/startup.sh` writes it at boot. Changed HTML means a new template, and the group rolls it out with zero downtime (because of: new VMs first, `max_unavailable_fixed = 0`, `min_ready_sec`, a `google-beta` field).

## Usage

```hcl
module "vm_site" {
  source = "../modules/vm-site"
  providers = {
    google      = google
    google-beta = google-beta
  }

  project_id               = var.project_id
  name                     = "vm-dev"
  region                   = "us-central1"
  site_dir                 = "${path.root}/../../site"
  machine_type             = "e2-micro"
  vm_service_account_email = "web-vm@my-project.iam.gserviceaccount.com"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.6 |
| google | >= 6.0 |
| google-beta | >= 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| google | >= 6.0 |
| google-beta | >= 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google-beta_google_compute_region_instance_group_manager.main](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_region_instance_group_manager) | resource |
| [google_compute_backend_service.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_service) | resource |
| [google_compute_firewall.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_health_check.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_health_check) | resource |
| [google_compute_instance_template.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template) | resource |
| [google_compute_network.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| disk\_type | Boot disk type. pd-standard keeps an e2-micro inside the Free Tier. | `string` | `"pd-standard"` | no |
| instance\_count | Number of VMs. 2+ gives zone redundancy. | `number` | `1` | no |
| labels | Labels for the VMs. | `map(string)` | `{}` | no |
| log\_sample\_rate | Fraction of LB requests to log (0.0 to 1.0). | `number` | `1` | no |
| machine\_type | VM machine type, e.g. e2-micro (dev) or e2-small (prod). | `string` | n/a | yes |
| name | Name prefix for resources, like "vm-dev". | `string` | n/a | yes |
| project\_id | Project to deploy into. | `string` | n/a | yes |
| region | Region for the VMs (spread across its zones). | `string` | n/a | yes |
| site\_dir | Local folder with index.html and 404.html. | `string` | n/a | yes |
| source\_image | Boot image (family link). | `string` | `"debian-cloud/debian-12"` | no |
| subnet\_cidr | CIDR of the web subnet. | `string` | `"10.10.0.0/24"` | no |
| vm\_service\_account\_email | Runtime service account for the VMs (created in bootstrap). | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| backend\_id | Backend service ID, for the frontend's URL map. |
| firewall\_name | Firewall rule that admits only Google's load balancer and health checks. |
| health\_check\_id | Health check used by the load balancer and for autohealing. |
| instance\_group | The regional managed instance group (MIG). |
| instance\_template | Current instance template (changes on every HTML change). |
| nat\_name | Cloud NAT gateway (outbound only). |
| network\_id | VPC network ID. |
| router\_name | Cloud Router used by Cloud NAT. |
| subnetwork\_id | Subnet the VMs run in. |
<!-- END_TF_DOCS -->
