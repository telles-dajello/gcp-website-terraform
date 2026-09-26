#!/usr/bin/env bash
# To get the help as suggested by best practices from GCP documentation: bash helpers/deploy.sh --help
set -euo pipefail
export MSYS_NO_PATHCONV=1

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

  if [ ! -f "$ENV.tfstate" ] && gcloud storage buckets describe "gs://$STATE_BUCKET" --project "$PROJECT" >/dev/null 2>&1; then
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