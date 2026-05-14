#!/usr/bin/env bash
set -euo pipefail

################################################################################
# bootstrap.sh — Full EKS platform deployment from scratch
# Usage: ./scripts/bootstrap.sh [dev|prod]
################################################################################

ENV=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

info "🚀 Bootstrapping EKS Platform — Environment: $ENV"

# ── Prerequisites check ───────────────────────────────────────────────────────
info "Checking prerequisites..."
for tool in terraform kubectl helm aws jq; do
  command -v "$tool" &>/dev/null || error "Missing required tool: $tool"
done

aws sts get-caller-identity &>/dev/null || error "AWS credentials not configured"
info "AWS Identity: $(aws sts get-caller-identity --query 'Arn' --output text)"

# ── Terraform ─────────────────────────────────────────────────────────────────
info "Deploying infrastructure with Terraform..."
cd "$ROOT_DIR/terraform/envs/$ENV"

terraform init
terraform plan -out=tfplan
terraform apply -auto-approve tfplan

CLUSTER_NAME=$(terraform output -raw cluster_name)
AWS_REGION=$(terraform output -raw aws_region)

info "EKS cluster: $CLUSTER_NAME in $AWS_REGION"

# ── Update kubeconfig ─────────────────────────────────────────────────────────
info "Updating kubeconfig..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
kubectl cluster-info

# ── Helm repos ────────────────────────────────────────────────────────────────
info "Adding Helm repos..."
helm repo add aws-load-balancer-controller https://aws.github.io/eks-charts
helm repo add keda                         https://kedacore.github.io/charts
helm repo add grafana                      https://grafana.github.io/helm-charts
helm repo add prometheus-community         https://prometheus-community.github.io/helm-charts
helm repo update

# ── Namespaces ────────────────────────────────────────────────────────────────
info "Creating namespaces..."
kubectl apply -f "$ROOT_DIR/k8s/namespaces/"

# ── AWS Load Balancer Controller ──────────────────────────────────────────────
info "Installing AWS Load Balancer Controller..."
helm upgrade --install aws-load-balancer-controller \
  aws-load-balancer-controller/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --wait

# ── KEDA ─────────────────────────────────────────────────────────────────────
info "Installing KEDA..."
helm upgrade --install keda keda/keda \
  --namespace keda --create-namespace \
  --wait

# ── Apply KEDA ScaledObjects ──────────────────────────────────────────────────
info "Applying KEDA ScaledObjects..."
SQS_URLS=$(terraform output -json sqs_queue_urls)
for queue in content-jobs market-data ai-jobs notification; do
  QUEUE_URL=$(echo "$SQS_URLS" | jq -r ".\"$queue\"")
  warn "Set queueURL for $queue-queue: $QUEUE_URL"
done
kubectl apply -f "$ROOT_DIR/k8s/keda/"

# ── Monitoring stack ──────────────────────────────────────────────────────────
info "Installing monitoring stack (Prometheus + Grafana)..."
helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=changeme \
  --wait

# ── Application services ──────────────────────────────────────────────────────
info "Deploying application services..."
ECR_URLS=$(terraform output -json ecr_urls)
IRSA_ARNS=$(terraform output -json irsa_role_arns)

for chart in api-router content-services auth-service core-services ai-services background-workers; do
  info "Deploying $chart..."
  helm upgrade --install "$chart" "$ROOT_DIR/helm/$chart/" \
    --namespace platform \
    --create-namespace \
    --set image.tag=latest \
    --wait --timeout 5m || warn "$chart deploy had issues — check logs"
done

# ── Ingress ───────────────────────────────────────────────────────────────────
info "Applying Ingress..."
kubectl apply -f "$ROOT_DIR/k8s/ingress/"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
info "✅ Bootstrap complete!"
echo ""
echo "  Cluster:   $CLUSTER_NAME"
echo "  Region:    $AWS_REGION"
echo "  Namespace: platform"
echo ""
echo "  kubectl get pods -n platform"
echo "  kubectl port-forward svc/kube-prometheus-grafana 3000:80 -n monitoring"
echo "    → Grafana: http://localhost:3000 (admin/changeme)"
