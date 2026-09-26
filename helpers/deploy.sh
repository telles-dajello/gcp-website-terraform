#!/usr/bin/env bash
# To get the help as suggested by best practices from GCP documentation: bash helpers/deploy.sh --help
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  PROJECT=<gcp-project-id> ENV=<dev|prod> bash helpers/deploy.sh bootstrap   # once per project
  bash helpers/deploy.sh --help   # this text
EOF
}

CMD=${1:-}
shift || true
EXTRA=("$@") # anything after the command goes to terraform unchanged

case "$CMD" in
  -h | --help | help) usage; exit 0 ;;
  bootstrap) ;;
  *) usage >&2; exit 1 ;;
esac

ROOT=$(cd "$(dirname "$0")/.." && pwd)

: "${PROJECT:?set PROJECT to your Google Cloud project ID}"
: "${ENV:?set ENV to dev or prod}"

STATE_BUCKET="$PROJECT-tfstate"
APPROVE=""
[ "${AUTO_APPROVE:-0}" = "1" ] && APPROVE="-input=false -auto-approve"

# bootstrap: and other API and bucket might come in after some other files are set and working
bootstrap() {
  cd "$ROOT/terraform/bootstrap"
  local vars=(-var "project_id=$PROJECT" -var "environment=$ENV")
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
    echo ">> First run: temporary local state, then moved into gs://$STATE_BUCKET"
    printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
    terraform init -input=false -reconfigure -backend-config="path=$ENV.tfstate"
    terraform apply $APPROVE "${vars[@]}"
    rm backend_override.tf
    terraform init -input=false -migrate-state -force-copy -backend-config="bucket=$STATE_BUCKET" -backend-config="prefix=bootstrap"
    rm -f "$ENV.tfstate" "$ENV.tfstate.backup"
  fi
  terraform output
}

case "$CMD" in
  bootstrap) bootstrap ;;
esac