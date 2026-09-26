#!/usr/bin/env bash
# To get the help as suggested by best practices from GCP documentation: bash helpers/deploy.sh --help
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  PROJECT=<gcp-project-id> ENV=<dev|prod> GITHUB_REPO=<owner/repo> bash helpers/deploy.sh bootstrap   # once per project
  add DOMAIN=<your-domain.com> only in prod, to create the Cloud DNS zone; after using, use it on every re-run.
  PROJECT=<gcp-project-id> ENV=<dev|prod> bash helpers/deploy.sh plan|apply|destroy|output [extra terraform args]
  bash helpers/deploy.sh --help   # this text

Per-project parameters (region, machine type, domains...) live in terraform/envs/<ENV>.tfvars.
Set AUTO_APPROVE=1 to skip the "yes" prompt (for the CI).
EOF
}

CMD=${1:-}
shift || true
EXTRA=("$@") # anything after the command goes to terraform unchanged

case "$CMD" in
  -h | --help | help) usage; exit 0 ;;
  bootstrap | plan | apply | destroy | output) ;;
  *) usage >&2; exit 1 ;;
esac

ROOT=$(cd "$(dirname "$0")/.." && pwd)

: "${PROJECT:?set PROJECT to your Google Cloud project ID}"
: "${ENV:?set ENV to dev or prod}"

STATE_BUCKET="$PROJECT-tfstate"
ENV_FILE="$ROOT/terraform/envs/$ENV.tfvars"
APPROVE=""
[ "${AUTO_APPROVE:-0}" = "1" ] && APPROVE="-input=false -auto-approve"

[ -f "$ENV_FILE" ] || { echo "No settings file $ENV_FILE"; exit 1; }

# bootstrap: APIs, state bucket, service accounts, IAM, WIF
bootstrap() {
  : "${GITHUB_REPO:?set GITHUB_REPO to owner/repo}"
  # WIF trusts the numeric repository ID, not the name (following GCP best practises).
  local repo_id=${GITHUB_REPO_ID:-}
  if [ -z "$repo_id" ]; then
    repo_id=$(curl -fsS "https://api.github.com/repos/$GITHUB_REPO" | sed -n 's/^  "id": \([0-9]*\),*$/\1/p' | head -n 1) || true
  fi
  [ -n "$repo_id" ] || { echo "Could not find the ID of $GITHUB_REPO on GitHub. Is the repo public? Or set GITHUB_REPO_ID."; exit 1; }
  echo ">> $GITHUB_REPO has repository ID $repo_id"

  cd "$ROOT/terraform/bootstrap"
  local vars=(-var "project_id=$PROJECT" -var "environment=$ENV" -var "github_repository=$GITHUB_REPO" -var "github_repository_id=$repo_id")
  [ -n "${DOMAIN:-}" ] && vars+=(-var "dns_domain=$DOMAIN")
  vars+=(${EXTRA[@]+"${EXTRA[@]}"})

  # Does the state bucket exist? Only "not found" means a first run.
  # Any other gcloud error (not logged in, gcloud broken...) stops here.
  local check bucket_exists=0
  if check=$(gcloud storage buckets describe "gs://$STATE_BUCKET" --project "$PROJECT" --format="value(name)" 2>&1); then
    bucket_exists=1
  elif ! grep -qiE "not found|404" <<<"$check"; then
    echo "Could not check gs://$STATE_BUCKET:"
    echo "$check"
    exit 1
  fi

  if [ ! -f "$ENV.tfstate" ] && [ "$bucket_exists" = 1 ]; then
    # Normal re-run: state already lives in the bucket.
    terraform init -input=false -reconfigure -backend-config="bucket=$STATE_BUCKET" -backend-config="prefix=bootstrap"
    terraform apply $APPROVE "${vars[@]}"
  else
    # First run: the bucket doesn't exist yet, so start with local state...
    echo ">> First run: temporary local state, then moved into gs://$STATE_BUCKET"
    printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
    terraform init -input=false -reconfigure -backend-config="path=$ENV.tfstate"
    terraform apply $APPROVE "${vars[@]}"
    # ...then move it into the bucket that was just created.
    rm backend_override.tf
    terraform init -input=false -migrate-state -force-copy \
      -backend-config="bucket=$STATE_BUCKET" -backend-config="prefix=bootstrap"
    rm -f "$ENV.tfstate" "$ENV.tfstate.backup"
  fi
  terraform output
}

# live: the website
live_init() {
  cd "$ROOT/terraform/live"
  terraform init -input=false -reconfigure -backend-config="bucket=$STATE_BUCKET" -backend-config="prefix=live" >/dev/null
}

LIVE_VARS=(-var "project_id=$PROJECT" -var "environment=$ENV" -var-file="../envs/$ENV.tfvars")

# After an apply, clear the CDN cache so a changed page shows up right away.
invalidate_cdn() {
  local url_map
  url_map=$(terraform output -raw bucket_site_url_map 2>/dev/null || true)
  if [ -n "$url_map" ]; then
    gcloud compute url-maps invalidate-cdn-cache "$url_map" --path "/*" --global --async --project "$PROJECT"
  fi
}

case "$CMD" in
  bootstrap) bootstrap ;;
  plan)      live_init; terraform plan -input=false "${LIVE_VARS[@]}" ${EXTRA[@]+"${EXTRA[@]}"} ;;
  apply)     live_init; terraform apply $APPROVE "${LIVE_VARS[@]}" ${EXTRA[@]+"${EXTRA[@]}"}; invalidate_cdn; terraform output ;;
  destroy)   live_init; terraform destroy $APPROVE "${LIVE_VARS[@]}" ${EXTRA[@]+"${EXTRA[@]}"} ;;
  output)    live_init; terraform output ;;
esac