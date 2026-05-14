#!/usr/bin/env bash
set -euo pipefail

ENV=${1:-dev}
ROOT_DIR="$(dirname "$(dirname "${BASH_SOURCE[0]}")")"

echo "⚠️  Destroying EKS Platform — Environment: $ENV"
read -r -p "Are you sure? Type 'yes' to confirm: " confirm
[[ "$confirm" == "yes" ]] || { echo "Aborted."; exit 0; }

# Remove Helm releases first
for chart in api-router content-services auth-service core-services ai-services background-workers; do
  helm uninstall "$chart" -n platform 2>/dev/null || true
done
helm uninstall kube-prometheus -n monitoring 2>/dev/null || true
helm uninstall keda -n keda 2>/dev/null || true
helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || true

# Destroy Terraform
cd "$ROOT_DIR/terraform/envs/$ENV"
terraform destroy -auto-approve

echo "✅ Teardown complete."
