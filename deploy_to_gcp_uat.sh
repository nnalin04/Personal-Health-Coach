#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-my-project-poc-478915}"
ZONE="${ZONE:-us-central1-a}"
INSTANCE_NAME="${INSTANCE_NAME:-health-coach-uat}"
MACHINE_TYPE="${MACHINE_TYPE:-e2-medium}"

"$(dirname "$0")/deploy_to_gcp.sh" uat "$PROJECT_ID" "$ZONE" "$INSTANCE_NAME" "$MACHINE_TYPE"
