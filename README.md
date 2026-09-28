# Website hosting on Google Cloud with Terraform

One static HTML site, served two different ways, deployed with the same Terraform code into two Google Cloud projects, `dev` and `prod`. What follows is a series of reflections on how and why.

## Contents

- [Introduction](#introduction)
- [Summary](#summary)
- [Requirements checklist](#requirements-checklist)
- [Running the project](#running-the-project)
  - [See it running](#see-it-running)
  - [See the automatic deployment](#see-the-automatic-deployment)
  - [Reproduce it: dev in five commands](#reproduce-it-dev-in-five-commands)
  - [Reproduce it: prod, with or without a domain](#reproduce-it-prod-with-or-without-a-domain)
  - [Reproduce it: CI in your own fork](#reproduce-it-ci-in-your-own-fork)
  - [Other commands](#other-commands)
- [The choices in more detail](#the-choices-in-more-detail)
  - [Assumptions](#assumptions)
  - [Hosting options, and why these two](#hosting-options-and-why-these-two)
  - [Why not the others](#why-not-the-others)
  - [Security](#security)
  - [Repository layout, and why](#repository-layout-and-why)
- [Costs](#costs)
- [Time spent](#time-spent)

## Introduction

First I intend to present the main choices and the reasoning behind them. I will do it very briefly and directly first. After this section I will present the commands necessary to run this project, to see the automation in deployment in dev and prod for the two chosen approaches, and the code to reproduce the project as your own, with or without a domain.

After that, the following section will expand on each topic and present some references used. At the end the cost estimation and the time used will be presented as tables with short comments on each table.

## Summary

Assumptions. The challenge doesn't describe the site, so I started from some basic assumptions. I assumed a static HTML page, since the challenge said `A change to the HTML must cause a redeployment.`, and the fact that it is a Terraform challenge, and the site is secondary in this context. I assumed the site is for US users, with moderate traffic and occasional spikes, and no downtime when it's redeployed, since CI and auto redeployment are part of the challenge. I also assumed a context where the site would hold health data, since Hippo works under HIPAA. I only used Google Cloud products covered by Google's HIPAA agreement. The budget is small, so I kept all as close to the Free Tier as possible.

The two approaches. Google lists five products for hosting a website: Cloud Storage and Firebase Hosting for static sites, Compute Engine for virtual machines, GKE for containers, and Cloud Run for serverless. I chose the following two:

- Approach A, Cloud Storage + load balancer + Cloud CDN. This is the right tool for static HTML. There is nothing to run. The files stay in a private bucket. The CDN serves them close to users and serves as a buffer for spikes. And a redeploy just changes some files for others.
- Approach B, a Compute Engine managed instance group (nginx VMs) + load balancer. This is for the case of maintaining full control of the web server. VMs spread across zones, and rolling updates with zero downtime. It is also ready to grow into a dynamic app.

Both use the same load balancer module, on a reserved IP that never changes. It works with HTTPS on my domain in prod.

Why not the others. Firebase Hosting fails in two points: Terraform can't deploy the site's files (they use the Firebase CLI), and Firebase isn't covered by Google's HIPAA agreement (see [Google Cloud: HIPAA compliance on Google Cloud](https://cloud.google.com/security/compliance/hipaa)). GKE runs a whole cluster. For one page it would be overkill. Cloud Run needs a container image and a build pipeline to serve static files; it could become the first choice as soon as the site needs server code. If it wasn't for the container image and build pipeline it might be a better option for approach B.

Deployment. Everything is Terraform, with remote state in a bucket per project. After the first deployment, nobody runs a deploy command: a pull request into `develop` plans dev and its merge deploys dev; a pull request from `develop` into `main` plans prod and its merge deploys prod. GitHub Actions logs in to Google Cloud with Workload Identity Federation, so there are no keys anywhere.

## Requirements checklist

| Requirement | How it is met |
| --- | --- |
| All infrastructure in Terraform, `google` and `google-beta` | Everything under `terraform/`, with no manual Console steps; `google-beta` for the rolling-update field `min_ready_sec` in approach B |
| Remote state | A private, versioned Cloud Storage bucket per project, with state locking; bootstrap moves its own state into it after the first run (see [HashiCorp: Backend type: gcs](https://developer.hashicorp.com/terraform/language/backend/gcs)) |
| A change to the HTML causes a redeployment | Approach A: the file's md5 changes, so it is re-uploaded and the CDN cache cleared. Approach B: the instance template changes, so the VMs roll over. CI applies on every merge |
| Stable endpoint | A reserved global IP per approach, independent of the backends and certificates; the DNS names point to it |
| TLS (optional) | Done in prod: Google-managed certificates, HTTP redirected to HTTPS. Dev stays on HTTP |
| Multi-project with different parameters | The same code in `dev` and `prod`; the project comes from `PROJECT=`, and region, machine type, VM count and domains from `terraform/envs/<env>.tfvars` |

## Running the project

### See it running

| | Approach A: bucket + CDN | Approach B: VMs |
| --- | --- | --- |
| dev (HTTP on the reserved IP) | http://34.49.103.214 | http://34.149.149.188 |
| prod (HTTPS on the domain) | https://www.luisdajello.com | https://vm.luisdajello.com |

In prod, HTTP redirects to HTTPS, and the certificates are Google-managed. I will keep them up until the review is done, and destroy everything afterwards.

### See the automatic deployment

Each environment has its own branch, and changes are promoted by merging from one to the next, as Google's Terraform guide recommends (see [Google Cloud: Best practices for version control](https://docs.cloud.google.com/docs/terraform/best-practices/version-control)). The Actions tab of this repository shows every plan and apply. You can see the tests made by me.

A change to the site goes through two pull requests:

```bash
git switch develop && git pull
git switch -c feature/change-title
# make some edit to site/index.html to have something change and trigger a deploy
git commit -am "featute/site: change title" && git push -u origin feature/change-title

gh pr create --base develop --fill
#   plan-dev runs the tests and a plan against dev: the file in the bucket (A) and the VM template (B) change, nothing else
#   merge the pull request: apply-dev deploys dev

gh pr create --base main --head develop --title "release: change title" --body "Promote to prod"
#   promotion-source checks that the source is develop; plan-prod waits for approval, then plans prod
#   merge the pull request: apply-prod waits for approval, then deploys prod
```

CI runs the same `helpers/deploy.sh` as a person would, and Terraform decides what to redeploy. On the same IPs, approach A shows the change within a minute, because the deploy clears the CDN cache (see [Google Cloud: Invalidate cached content](https://docs.cloud.google.com/cdn/docs/invalidating-cached-content)), and approach B after the rolling update, a few minutes later.

There is a trade-off of having environment branches. Two pull requests necessary per change, and the risk of the branches drifting apart, since hotfixes go from `hotfix/*` into `main` and need to be merged back into `develop` straight away to avoid drift.

### Reproduce it: dev in five commands

The commands below use this repository, `telles-dajello/gcp-website-terraform`. Running them from a clone is enough to deploy both approaches into your own project. Bootstrap also makes your project trust the GitHub Actions of the repository named in `GITHUB_REPO`, which means mine. If you prefer your project to trust only your own copy, or want to run CI, fork the repository first, and replace `telles-dajello` and `gcp-website-terraform` with your GitHub user and fork name wherever they appear.

You need Terraform 1.7 or newer, the gcloud CLI, bash and a Google Cloud project with billing where you are the Owner.

```bash
gcloud auth login && gcloud auth application-default login
git clone https://github.com/telles-dajello/gcp-website-terraform.git && cd gcp-website-terraform
export PROJECT=<your-dev-project-id> ENV=dev GITHUB_REPO=<your-github-user>/gcp-website-terraform
bash helpers/deploy.sh bootstrap   # once per project: creates the state bucket, service accounts, IAM, GitHub login trust
bash helpers/deploy.sh apply       # both approaches; prints bucket_site_url and vm_site_url
```

A new load balancer needs 5 to 10 minutes before it answers.

### Reproduce it: prod, with or without a domain

```bash
# prod WITH a domain you own
export PROJECT=<your-prod-project-id> ENV=prod   GITHUB_REPO=telles-dajello/gcp-website-terraform DOMAIN=your-domain.com
bash helpers/deploy.sh bootstrap   # also creates the Cloud DNS zone and prints dns_name_servers
#   then you need to set those four name servers at your domain registrar (only once)
#   after that put www.your-domain.com and vm.your-domain.com in terraform/envs/prod.tfvars
bash helpers/deploy.sh apply       # certificates, HTTPS, redirect, DNS records; HTTPS will be live in about 15 min



# prod WITHOUT a domain (the same prod settings, served over HTTP on the IPs)
export PROJECT=<your-prod-project-id> ENV=prod GITHUB_REPO=telles-dajello/gcp-website-terraform
bash helpers/deploy.sh bootstrap
bash helpers/deploy.sh apply -var 'bucket_site_domains=[]' -var 'vm_site_domains=[]' -var manage_dns=false
```

Keep `DOMAIN=` on every following prod bootstrap if you used one: the DNS zone is protected, and a run without it stops instead of deleting the zone. `GITHUB_REPO` is the only repository whose GitHub Actions the project will trust.

### Reproduce it: CI in your own fork

1. Fork the repository, create a `develop` branch and make it the default branch.
2. Run bootstrap for each project with `GITHUB_REPO=<your-github-user>/<your-fork>`. It prints three values.
3. Under Settings -> Environments, create `dev` and `prod`. In each, add three variables (not secrets) from that project's bootstrap output: `GCP_PROJECT_ID`, `GCP_WIF_PROVIDER` and `GCP_DEPLOYER_SA`. Add yourself as a required reviewer on `prod`.
4. Protect both branches: `develop` requires a pull request and the `plan-dev` check; `main` requires a pull request and the `promotion-source` and `plan-prod` checks.

### Other commands

```bash
bash helpers/deploy.sh test        # the automated tests; no project, no credentials, no cost
bash helpers/deploy.sh destroy     # removes the website; bootstrap's foundations stay
gcloud projects delete $PROJECT    # removes everything else and stops all billing
```

`bash helpers/deploy.sh --help` lists the rest. In prod, empty the site bucket before `destroy`, since it is protected while it holds files: `gcloud storage rm --recursive --all-versions "gs://$PROJECT-site-prod/**"`.

## The choices in more detail

### Assumptions

The context is Hippo, a US company working under HIPAA.

- US users only.
  - Design: US regions for the VMs, the `US` multi-region for the prod bucket, and Cloud CDN.
  - If it were different: the load balancer and CDN are global already; I could add a second VM region nearer other users.
- Static HTML, no database, no user data.
  - Design: a bucket and a CDN are enough (A); B is ready for server-side logic but doesn't need it.
  - If it were different: server-side logic -> Cloud Run.
- Site might not deal with health data (PHI), but needs to be HIPAA-ready.
  - Design: only products covered by Google's HIPAA agreement (see [Google Cloud: HIPAA compliance on Google Cloud](https://cloud.google.com/security/compliance/hipaa)); the bucket is private.
  - If it were different: if any PHI then a BAA with Google, audit logging, and resources restricted to US locations (see [Google Cloud: Restrict resource locations](https://docs.cloud.google.com/organization-policy/restrict-locations)).
- Moderate traffic, with possible spikes.
  - Design: the CDN absorbs spikes for A; B runs 1 VM in dev and 2 in prod.
  - If it were different: if sustained heavy traffic then autoscaling on the VM group, or Cloud Run.
- No downtime on redeploy.
  - Design: approach B rolls out new VMs before removing old ones; approach A replaces files, and the CDN can serve cached pages if the bucket has trouble (see [Google Cloud: Serve stale content](https://docs.cloud.google.com/cdn/docs/serving-stale-content)).
  - If it were different: with brief downtime acceptable, a single VM would do.
- A small budget.
  - Design: small machines, using a Free Tier region (see [Google Cloud: Free Google Cloud features and trial offer](https://docs.cloud.google.com/free/docs/free-cloud-features)).
  - If it were different: more budget could mean larger machines, Cloud Armor, a second region for approach B.

Dev runs in `us-central1` and prod in `us-east1`.

### Hosting options, and why these two

Google's "Website hosting" guide lists four ways to host a website, with five products (see [Google Cloud: Website hosting](https://docs.cloud.google.com/architecture/web-serving-overview)):

- Static website: Cloud Storage and Firebase Hosting.  ---> For pages that "rarely change after they have been published".
- Virtual machines: Compute Engine.  ---> "complete control of the systems", but you configure and monitor them yourself.
- Containers: GKE.  ---> For componentized apps and microservices.
- Serverless: Cloud Run.  ---> Fully managed; "you only pay for the time that your code runs".

Two filters come from the challenge and the context. First, everything, including the HTML, is deployed by Terraform, and an HTML change must cause a redeployment. Second, only products covered by Google's HIPAA agreement.

**Approach A: Cloud Storage + load balancer + Cloud CDN.** Cloud Storage alone can't serve HTTPS on a custom domain; Google's own guide says to put a load balancer in front for that (see [Google Cloud: Website hosting](https://docs.cloud.google.com/architecture/web-serving-overview)). With it, the site gets a reserved IP, a Google-managed certificate and the CDN. Each file is a Terraform object tied to its md5, so a changed file is re-uploaded on the next apply (see [HashiCorp: google_storage_bucket_object](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object)). The bucket is private: only the load balancer's service agent may read it. The trade-offs are the load balancer's fixed cost, and that it can't run code.

**Approach B: Compute Engine managed instance group + load balancer.** nginx runs on small VMs, in a regional group spread across zones (see [Google Cloud: About regional MIGs](https://docs.cloud.google.com/compute/docs/instance-groups/regional-migs)). The HTML goes in the instance template, so a change creates a new template and the group rolls it out. New VMs are created first. None is removed before the new ones are healthy (see [Google Cloud: Automatically apply VM configuration updates in a MIG](https://docs.cloud.google.com/compute/docs/instance-groups/rolling-out-updates-to-managed-instance-groups)). That rollout setting, `min_ready_sec`, is a beta field, which is why the module uses the `google-beta` provider. The structure follows Google's guide for a load balancer with a MIG backend (see [Google Cloud: Set up a global external Application Load Balancer with a managed instance group backend](https://docs.cloud.google.com/load-balancing/docs/https/setup-global-ext-https-compute)), but with stricter rules in three ways:

- The VMs have no public IPs, and Cloud NAT gives them outbound access only (see [Google Cloud: Use Public NAT with Compute Engine](https://docs.cloud.google.com/nat/docs/gce-example)).
- The firewall admits only Google's load balancer and health-check ranges (see [Google Cloud: Firewall rules](https://docs.cloud.google.com/load-balancing/docs/firewall-rules)).
- The group is regional, and the VMs run as a dedicated service account that can only write logs.

The trade-offs are more cost, and redeploys that take minutes instead of seconds.

A and B share one frontend module: a reserved IP (see [Google Cloud: Reserve a static external IP address](https://docs.cloud.google.com/vpc/docs/reserve-static-external-ip-address)), a Google-managed certificate (see [Google Cloud: Use Google-managed SSL certificates](https://docs.cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs)), a TLS 1.2+ policy and an HTTP-to-HTTPS redirect. So the endpoint stays the same whichever backend is redeployed.

### Why not the others

- Firebase Hosting is technically strong and free at this size, but Terraform can't deploy the site: its Terraform resources are beta, and the version resource says "Static files are not supported at the moment" (see [HashiCorp: google_firebase_hosting_version](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/firebase_hosting_version)). The files ship with the Firebase CLI, outside Terraform. And no Firebase product is covered by Google's HIPAA agreement (see [Google Cloud: HIPAA compliance on Google Cloud](https://cloud.google.com/security/compliance/hipaa)).
- GKE runs a whole cluster for one static page (see [Google Cloud: Google Kubernetes Engine pricing](https://cloud.google.com/kubernetes-engine/pricing)). An HTML change would need an image build, a registry and a rollout.
- Cloud Run has no servers and scales to zero, but static files would need a container image built outside Terraform. HTTPS on my own domain needs either a load balancer (the same fixed cost as A) or domain mapping, which is in Preview and "not production-ready" (see [Google Cloud: Mapping custom domains](https://docs.cloud.google.com/run/docs/mapping-custom-domains)). It is the strongest runner-up.

I also rejected some variants inside these products:

- - Serving the site straight from the bucket, without a load balancer. Cloud Storage serves a custom domain only over HTTP, and every file would have to be public. I wanted HTTPS and a private bucket, so the load balancer was needed.
- A single VM is one point of failure, with downtime on every redeploy.

### Security

- No keys anywhere. CI logs in through GitHub's OIDC token and Workload Identity Federation, getting a short-lived token for a deployer service account, as Google recommends over service account keys (see [Google Cloud: Best practices for managing service account keys](https://docs.cloud.google.com/iam/docs/best-practices-for-managing-service-account-keys)). The GitHub variables only name the project, the service account and the provider. None of them is a secret.
- Each project's WIF provider only accepts tokens from this repository, matched by its numeric ID rather than its name (see [Google Cloud: Configure Workload Identity Federation with deployment pipelines](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines)), and from jobs running in the matching GitHub environment. Prod's environment requires my approval.
- Least privilege. The deployer has the narrowest predefined roles for load balancing, compute, network, security and storage, and no IAM or owner roles (see [Google Cloud: Use IAM securely](https://docs.cloud.google.com/iam/docs/using-iam-securely)). It can't create service accounts or grant roles: I create those once in bootstrap, as project Owner. Two of its permissions are limited to a single resource instead of the whole project. It can start VMs only as the VM service account, which can only write logs. It can manage DNS records only in the site's own zone.
- Private by default. The bucket enforces public access prevention and only the load balancer can read it. The VMs have no public IPs. The state buckets are private and versioned.

### Repository layout, and why

```
site/                      
terraform/
  bootstrap/               
  modules/
    https-frontend/        
    bucket-site/           
    vm-site/               
  live/                    
  envs/dev.tfvars          
  envs/prod.tfvars         
helpers/deploy.sh 
.github/workflows/
```

- Bootstrap is separate from the website. It creates what the website needs but must never create for itself: the state bucket, the IAM, the login trust for CI, and the DNS zone whose name servers are set at the registrar. A person with Owner rights runs it once, so CI never has permission to change IAM.
- Modules to separate the parts and one root to assemble them. Each approach and the shared load balancer are local modules with the standard `main.tf`, `variables.tf` and `outputs.tf`, as HashiCorp recommends (see [HashiCorp: Modules overview](https://developer.hashicorp.com/terraform/tutorials/modules/module)). Inside, the code follows Google's Terraform style guide: files grouped by purpose, a README per module generated with terraform-docs, and providers pinned in the root modules (see [Google Cloud: Best practices for general style and structure](https://docs.cloud.google.com/docs/terraform/best-practices/general-style-structure)).
- I chose one root instead of one folder per environment. Google recommends `environments/dev` and `environments/prod` folders, and advises against command-line variables (see [Google Cloud: Best practices for root modules](https://docs.cloud.google.com/docs/terraform/best-practices/root-modules)). I deliberately used one root, `live/`, with the settings in `envs/<env>.tfvars`, and `deploy.sh` passes only two values, `project_id` and `environment`. That keeps deployment to one short command in any project, and guarantees dev and prod run exactly the same code for both approaches. With more environments or a team, I would move to Google's layout, with `live/` becoming a module that each environment calls.

The per-environment parameters, all in `envs/<env>.tfvars`:

| Parameter | dev | prod |
| --- | --- | --- |
| Region | `us-central1` | `us-east1` |
| Machine type | `e2-micro` | `e2-small` |
| Number of VMs | 1 | 2 |
| Bucket location | `US-CENTRAL1` | `US` |
| Domains (turn on TLS) and DNS records | none, HTTP on the IPs | `www.` and `vm.luisdajello.com` |

## Costs

My monthly estimates from Google's pricing pages.

| Item | Rate | dev | prod |
| --- | --- | --- | --- |
| Load balancer forwarding rules (the first 5 per project are billed together) | US$0.025/h (see [Google Cloud: Cloud Load Balancing pricing](https://cloud.google.com/load-balancing/pricing)) | US$18.25 | US$18.25 |
| Approach A: storage, CDN egress, load balancer data | per use (see [Google Cloud: Cloud CDN pricing](https://cloud.google.com/cdn/pricing)) | < US$1 | < US$2 |
| Approach B: VMs | e2-micro ≈ US$6.11, e2-small ≈ US$12.23 (see [Google Cloud: VM instance pricing](https://cloud.google.com/compute/vm-instance-pricing)) | 1 × e2-micro = US$0 (Free Tier) | 2 × e2-small ≈ US$24.50 |
| Approach B: Cloud NAT | per VM + NAT IP + data (see [Google Cloud: Cloud NAT pricing](https://cloud.google.com/nat/pricing)) | ≈ US$4.70 | ≈ US$5.70 |
| Cloud DNS zone | US$0.20/zone-month (see [Google Cloud: Cloud DNS pricing](https://cloud.google.com/dns/pricing)) | none | ≈ US$0.20 |
| Total | | ≈ US$23/month | ≈ US$50/month |

- The load balancer is the fixed cost, even with no traffic. A and B share it in each project, and HTTPS adds nothing: prod's 4 forwarding rules stay inside the first 5 that are billed together.
- Approach A alone would be about US$18/month. The only cost that grows with traffic is the CDN's charge for the data it sends to users.
- Approach B adds the VMs and NAT. A pre-built VM image would remove NAT and save about US$5/month per environment. But this would involve more build steps outside Terraform.

## Time spent

| Day | Reasearching (h) | Building (h) | Notes |
| --- | --- | --- | --- |
| Wednesday | 3-4h | - | Listing documentation and preparing reading plan |
| Wednesday | 3-4h | - | Reading and reviewing system design and infra best practices |
| Thursday | 3-4h | - | Organizing building plan as reading went along |
| Friday | 1-2h | 2h | Accounts, projects, domain, tools, Terraform basics, choosing the approaches, repository setup |
| Saturday | 3h | 7h | Bootstrap for dev and prod, WIF, DNS. Both approaches in dev and prod, HTTPS, tests, CI |
| Sunday | | 1h | CI demonstration, README |
| Total | 13-17h | 10h | |

- Most of my time has been reviewing documentation and reviewing system design trade-offs to decide on the approaches. The hours building are the literal time with hands on keyboard to make it happen.
