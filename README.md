# 101GenAI Platform - Terraform Infrastructure as Code

This repository contains a comprehensive Terraform Infrastructure as Code (IaC) solution for deploying the 101GenAI platform on both AWS and GCP. The infrastructure is fully config-driven and supports multi-cloud deployments.

## 🏗️ Architecture Overview

The platform deploys the following components:
- **Kubernetes Cluster** (EKS on AWS / GKE on GCP)
- **MongoDB** (Document database with replica set)
- **PostgreSQL** (Relational database for Keycloak)
- **Redis** (Caching and message broker)
- **Weaviate** (Vector database for AI/ML workloads)
- **Keycloak** (Identity and access management)
- **Backend API** (Application backend services)
- **Frontend** (Web application frontend)
- **Celery Workers** (Asynchronous task processing)
- **NGINX Ingress Controller** (Load balancing and routing)

## 📁 Project Structure

\`\`\`
terraform-iac/
├── config.yaml                 # Main configuration file
├── main.tf                     # Root Terraform configuration
├── variables.tf                # Input variables
├── outputs.tf                  # Output values
├── modules/
│   ├── aws/                    # AWS-specific infrastructure
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── gcp/                    # GCP-specific infrastructure
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── workloads/              # Kubernetes workloads
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── jobs/                       # Kubernetes Jobs for initialization
│   ├── postgres-migration.yaml
│   ├── mongo-replica-sync.yaml
│   ├── weaviate-schema-setup.yaml
│   ├── redis-config-setup.yaml
│   └── init-secrets.yaml
├── config-aws-example.yaml     # AWS deployment example
├── config-gcp-example.yaml     # GCP deployment example
└── README.md
\`\`\`

## 🚀 Quick Start

### Prerequisites

1. **Terraform** >= 1.0
2. **Cloud CLI Tools**:
   - AWS: `aws-cli` configured with appropriate credentials
   - GCP: `gcloud` CLI configured with appropriate credentials
3. **kubectl** for Kubernetes management
4. **helm** for Helm chart management

### AWS Deployment

1. **Configure AWS credentials**:
   \`\`\`bash
   aws configure
   \`\`\`

2. **Copy and customize the AWS configuration**:
   \`\`\`bash
   cp config-aws-example.yaml config.yaml
   # Edit config.yaml with your specific requirements
   \`\`\`

3. **Deploy the infrastructure**:
   \`\`\`bash
   terraform init
   terraform plan
   terraform apply
   \`\`\`

4. **Configure kubectl**:
   \`\`\`bash
   aws eks update-kubeconfig --region ap-south-1 --name 101GenAI-Public-Beta-Cluster-Webknot
   \`\`\`

### GCP Deployment

1. **Configure GCP credentials**:
   \`\`\`bash
   gcloud auth application-default login
   gcloud config set project YOUR_PROJECT_ID
   \`\`\`

2. **Copy and customize the GCP configuration**:
   \`\`\`bash
   cp config-gcp-example.yaml config.yaml
   # Edit config.yaml with your specific requirements
   \`\`\`

3. **Deploy the infrastructure**:
   \`\`\`bash
   terraform init
   terraform plan
   terraform apply
   \`\`\`

4. **Configure kubectl**:
   \`\`\`bash
   gcloud container clusters get-credentials 101genai-platform-cluster-gcp --region asia-south1
   \`\`\`

## ⚙️ Configuration

The entire deployment is driven by the `config.yaml` file. Key configuration sections:

### Cloud Provider
\`\`\`yaml
provider: "aws"  # or "gcp"
region: "ap-south-1"
\`\`\`

### Cluster Settings
\`\`\`yaml
cluster_name: "101genai-platform-cluster"
nodes:
  machine_type: "t3a.xlarge"  # AWS or "e2-standard-4" for GCP
  node_count: 3
\`\`\`

### Service Configuration
Each service can be configured with:
- **Replicas**: Number of instances
- **Resources**: CPU and memory requests/limits
- **Storage**: Persistent volume configuration

Example:
\`\`\`yaml
services:
  mongodb:
    replicas: 3
    resources:
      requests:
        cpu: "500m"
        memory: "1Gi"
      limits:
        cpu: "1000m"
        memory: "2Gi"
    storage:
      size: "20Gi"
      access_modes: ["ReadWriteMany"]
\`\`\`

## 🔧 Post-Deployment Setup

After successful deployment, run the initialization jobs:

\`\`\`bash
# Apply all initialization jobs
kubectl apply -f jobs/

# Monitor job completion
kubectl get jobs
kubectl logs job/postgres-migration
kubectl logs job/mongo-replica-sync
kubectl logs job/weaviate-schema-setup
kubectl logs job/redis-config-setup
kubectl logs job/init-secrets
\`\`\`

## 📊 Monitoring and Verification

### Check Cluster Status
\`\`\`bash
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get services
kubectl get ingress
\`\`\`

### Verify Storage
\`\`\`bash
kubectl get pv
kubectl get pvc
kubectl get storageclass
\`\`\`

### Check Service Endpoints
\`\`\`bash
# Get ingress controller external IP
kubectl get svc -n ingress-nginx

# Check individual service endpoints
kubectl get svc | grep LoadBalancer
\`\`\`

## 🔐 Security Considerations

1. **Secrets Management**: The deployment creates several Kubernetes secrets. Update them with actual values:
   \`\`\`bash
   kubectl edit secret app-secrets
   kubectl edit secret external-secrets
   \`\`\`

2. **Network Security**: 
   - AWS: Security groups are configured for minimal required access
   - GCP: Firewall rules follow least-privilege principles

3. **RBAC**: Kubernetes RBAC is configured for service accounts

## 🛠️ Customization

### Adding New Services
1. Add service configuration to `config.yaml`
2. Update `modules/workloads/main.tf` with new service deployment
3. Create corresponding Kubernetes manifests or Helm releases

### Scaling Services
Update the `replicas` count in `config.yaml` and run:
\`\`\`bash
terraform apply
\`\`\`

### Resource Adjustments
Modify the `resources` section in `config.yaml` for any service and apply changes.

## 🔄 Updates and Maintenance

### Updating Kubernetes Versions
1. Update cluster version in the respective module (`modules/aws/main.tf` or `modules/gcp/main.tf`)
2. Run `terraform plan` and `terraform apply`

### Updating Application Images
Update image tags in the workloads module and apply changes.

## 🧹 Cleanup

To destroy the entire infrastructure:
\`\`\`bash
terraform destroy
\`\`\`

**Warning**: This will delete all resources including data. Ensure you have backups if needed.

## 📞 Support

For issues and questions:
1. Check the Terraform plan output for any errors
2. Verify cloud provider credentials and permissions
3. Check Kubernetes cluster status and logs
4. Review the original AWS EKS Setup guide for manual troubleshooting steps

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.
