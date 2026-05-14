# 🚀 EKS Platform — GitLab CI/CD → ECR → EKS + SQS

> Production-grade AWS EKS microservices platform with full IaC (Terraform), Helm charts, GitLab CI/CD, KEDA autoscaling, and observability stack.

---

## 📐 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                      GitLab CI/CD Pipeline                          │
│  Developer → GitLab Repo+CI Runner → Build Docker → Push ECR →     │
│  Deploy EKS (helm upgrade)                                          │
│  ✅ GitLab uses AWS OIDC (no static keys)                           │
└─────────────────────────────────────────────────────────────────────┘
                              │
                    docker push / helm upgrade
                              │
┌─────────────────────────────────────────────────────────────────────┐
│  AWS Region                                                         │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  PUBLIC SUBNET                                                │  │
│  │  CloudFront → ALB Ingress (Load Balancer)                    │  │
│  │  Next.js/Static → S3                                         │  │
│  │  Route 53 DNS ← HTTPS ← End Users (Web/Mobile)              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                              │                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  PRIVATE SUBNET — EKS Cluster (Kubernetes)                   │  │
│  │                                                              │  │
│  │  API Router (Node.js) — Single Entry Point (Nginx)           │  │
│  │         │          │           │           │                 │  │
│  │  Content      Auth       Core Svc     AI Services           │  │
│  │  Services     Service    Services     ┌──────────┐          │  │
│  │  ┌──────┐  ┌────────┐  ┌────────┐   │AI Summary│          │  │
│  │  │Article│  │  OTP   │  │Search  │   │Audio Gen │          │  │
│  │  │Company│  │Handler │  │Service │   └──────────┘          │  │
│  │  │Sector │  │Session │  │User Svc│         │               │  │
│  │  │Analyt.│  │Handler │  └────────┘    LLM Provider         │  │
│  │  │RDS PG │  │Redis   │  OpenSearch    (OpenAI/Bedrock)     │  │
│  │  │S3     │  │RDS PG  │  RDS PG                             │  │
│  │  └──────┘  └────────┘                                      │  │
│  │                                                              │  │
│  │  ┌──────────── Amazon SQS — Async Job Queues ─────────────┐ │  │
│  │  │ content-jobs-queue  market-data-queue                   │ │  │
│  │  │ ai-jobs-queue       notification-queue                  │ │  │
│  │  └────────────────────────────────────────────────────────┘ │  │
│  │                                                              │  │
│  │  Background Workers (EKS Deployments — KEDA autoscale)      │  │
│  │  Content Worker │ Market Data Worker │ AI Worker │ Notif.   │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Observability                                                │  │
│  │  Prometheus → Grafana Dashboards                             │  │
│  │  Loki / Tempo / Mimir (Logs/Traces/Metrics)                  │  │
│  │  CloudWatch AWS Alarms                                       │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘

External Providers:
  • LLM Provider (OpenAI / AWS Bedrock)
  • SES / SendGrid (Email)
  • Market Data APIs (Financial feeds)
  • OAuth
```

> **See full architecture diagram:** [`docs/architecture.png`](docs/eks-platform/docs/architecture.png)
  #eks-platform/docs/architecture.png
---

## 📁 Project Structure

```
eks-platform/
├── terraform/                    # All infrastructure as code
│   ├── modules/
│   │   ├── vpc/                  # VPC, subnets, NAT, IGW
│   │   ├── eks/                  # EKS cluster + node groups
│   │   ├── ecr/                  # ECR repositories per service
│   │   ├── rds/                  # PostgreSQL RDS instances
│   │   ├── elasticache/          # Redis ElastiCache
│   │   ├── sqs/                  # SQS queues (4 queues)
│   │   ├── alb/                  # Application Load Balancer
│   │   ├── iam/                  # IRSA roles, OIDC for GitLab
│   │   ├── route53/              # DNS records
│   │   └── cloudwatch/           # Alarms & log groups
│   └── envs/
│       ├── dev/                  # Dev environment tfvars
│       └── prod/                 # Prod environment tfvars
├── helm/                         # Helm charts per service
│   ├── api-router/
│   ├── content-services/
│   ├── auth-service/
│   ├── core-services/
│   ├── ai-services/
│   ├── background-workers/
│   └── monitoring/               # Prometheus + Grafana stack
├── services/                     # Application source code stubs
│   ├── api-router/               # Node.js + Nginx gateway
│   ├── content-service/          # Article/Company/Sector/Analytics
│   ├── auth-service/             # OTP + Session management
│   ├── core-service/             # Search + User services
│   ├── ai-service/               # AI Summary + Audio Gen
│   └── background-worker/        # SQS consumers (KEDA)
├── k8s/                          # Raw Kubernetes manifests
│   ├── namespaces/
│   ├── keda/                     # ScaledObjects for each worker
│   └── ingress/                  # ALB Ingress definitions
├── scripts/                      # Utility scripts
│   ├── bootstrap.sh              # One-shot cluster bootstrap
│   └── destroy.sh                # Teardown script
└── .github/workflows/            # GitHub Actions (mirror of GitLab CI)
    └── ci-cd.yml
```

---

## ⚡ Quick Start — Deploy Everything from Scratch

### Prerequisites

```bash
# Install required tools
brew install terraform kubectl helm awscli
brew install kustomize jq

# Verify versions
terraform --version   # >= 1.6
kubectl version       # >= 1.28
helm version          # >= 3.13
aws --version         # >= 2.x
```

### 1. Configure AWS Credentials

```bash
aws configure
# or use SSO:
aws sso login --profile your-profile
```

### 2. Clone and Bootstrap

```bash
git clone https://github.com/YOUR_USERNAME/eks-platform.git
cd eks-platform

# Make bootstrap executable
chmod +x scripts/bootstrap.sh

# Run full infrastructure deploy (dev)
./scripts/bootstrap.sh dev
```

### 3. Manual Step-by-Step

```bash
# Step 1: Deploy infrastructure
cd terraform/envs/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Step 2: Update kubeconfig
aws eks update-kubeconfig \
  --name $(terraform output -raw cluster_name) \
  --region $(terraform output -raw aws_region)

# Step 3: Install cluster add-ons
helm repo add aws-load-balancer-controller \
  https://aws.github.io/eks-charts
helm repo add keda https://kedacore.github.io/charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts
helm repo update

# Install ALB Controller
helm upgrade --install aws-load-balancer-controller \
  aws-load-balancer-controller/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$(terraform output -raw cluster_name) \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Install KEDA
helm upgrade --install keda keda/keda \
  --namespace keda --create-namespace

# Step 4: Create namespaces
kubectl apply -f k8s/namespaces/

# Step 5: Deploy KEDA ScaledObjects
kubectl apply -f k8s/keda/

# Step 6: Deploy all microservices via Helm
for chart in api-router content-services auth-service \
             core-services ai-services background-workers; do
  helm upgrade --install $chart helm/$chart/ \
    --namespace platform \
    -f helm/$chart/values.yaml
done

# Step 7: Deploy monitoring stack
helm upgrade --install monitoring helm/monitoring/ \
  --namespace monitoring --create-namespace
```

---

## 🔧 Terraform Modules

| Module | Resources Created |
|--------|------------------|
| `vpc` | VPC, public/private subnets, NAT Gateway, IGW, route tables |
| `eks` | EKS cluster, managed node groups, OIDC provider |
| `ecr` | One ECR repo per microservice |
| `rds` | PostgreSQL instances (content, auth, core DBs) |
| `elasticache` | Redis cluster for auth sessions |
| `sqs` | 4 queues: content-jobs, market-data, ai-jobs, notification |
| `alb` | ALB, target groups, listener rules |
| `iam` | IRSA roles per service, GitLab OIDC federation |
| `route53` | A records, ACM cert validation |
| `cloudwatch` | Log groups, metric alarms, dashboards |

---

## 🐳 Microservices

| Service | Port | DB | Description |
|---------|------|-----|-------------|
| api-router | 3000 | — | Node.js + Nginx single entry point |
| content-service | 3001 | RDS PG + S3 | Article, Company, Sector, Analytics |
| auth-service | 3002 | RDS PG + Redis | OTP handler, session handler |
| core-service | 3003 | RDS PG + OpenSearch | Search, User services |
| ai-service | 3004 | — | AI Summary, Audio Gen (calls LLM APIs) |
| background-worker | — | — | SQS consumers, KEDA autoscaled |

---

## 📨 SQS Queue Architecture

```
Services → publish → SQS Queues → consume → Background Workers

content-jobs-queue    →  Content Worker   (process articles)
market-data-queue     →  Market Worker    (financial feed ingestion)
ai-jobs-queue         →  AI Worker        (async AI processing)
notification-queue    →  Notif. Worker    (email via SES/SendGrid)
```

KEDA scales workers 0→N based on queue depth (default: 1 worker per 10 messages).

---

## 🔐 Security

- **No static AWS keys** — GitLab uses OIDC federation to assume IAM roles
- **IRSA** (IAM Roles for Service Accounts) — each pod has least-privilege IAM role
- **Private subnets** — EKS nodes never exposed to internet
- **Secrets** stored in AWS Secrets Manager, injected via External Secrets Operator
- **ECR image scanning** enabled on push
- **RDS encrypted** at rest with KMS
- **SQS encrypted** with AWS-managed keys

---

## 📊 Observability

| Tool | Purpose |
|------|---------|
| Prometheus | Metrics scraping from all pods |
| Grafana | Dashboards for latency, throughput, errors |
| Loki | Log aggregation |
| Tempo | Distributed tracing |
| Mimir | Long-term metrics storage |
| CloudWatch | AWS-native alarms + EKS control plane logs |

Access Grafana:
```bash
kubectl port-forward svc/grafana 3000:80 -n monitoring
# open http://localhost:3000  (admin/admin)
```

---

## 🚀 CI/CD Pipeline (GitLab)

```yaml
stages:
  - build    # docker build + push to ECR (OIDC, no keys)
  - test     # unit + integration tests
  - deploy   # helm upgrade --install on EKS
```

GitLab CI uses AWS OIDC:
```
GitLab Job → assume IAM role (OIDC) → push ECR → helm upgrade EKS
```

---

## 🌍 Environments

| Env | Namespace | Node Type | Min Nodes |
|-----|-----------|-----------|-----------|
| dev | platform-dev | t3.medium | 2 |
| prod | platform | m5.xlarge | 3 |

---

## 🧹 Teardown

```bash
chmod +x scripts/destroy.sh
./scripts/destroy.sh dev
```

---

## 📝 License

MIT — free to use for any project.
