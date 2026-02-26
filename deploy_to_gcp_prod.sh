#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-my-project-poc-478915}"
ZONE="${ZONE:-us-central1-a}"
INSTANCE_NAME="${INSTANCE_NAME:-health-coach-prod}"
MACHINE_TYPE="${MACHINE_TYPE:-e2-standard-2}"

"$(dirname "$0")/deploy_to_gcp.sh" prod "$PROJECT_ID" "$ZONE" "$INSTANCE_NAME" "$MACHINE_TYPE"
