#!/bin/bash

# 101GenAI Platform Deployment Script
# This script automates the deployment of the 101GenAI platform using Terraform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command_exists terraform; then
        missing_tools+=("terraform")
    fi
    
    if ! command_exists kubectl; then
        missing_tools+=("kubectl")
    fi
    
    if ! command_exists helm; then
        missing_tools+=("helm")
    fi
    
    # Check config file
    if [ ! -f "config.yaml" ]; then
        print_error "config.yaml not found. Please copy and customize config-aws-example.yaml or config-gcp-example.yaml"
        exit 1
    fi
    
    # Read provider from config
    PROVIDER=$(grep "^provider:" config.yaml | awk '{print $2}' | tr -d '"')
    
    if [ "$PROVIDER" = "aws" ]; then
        if ! command_exists aws; then
            missing_tools+=("aws-cli")
        fi
    elif [ "$PROVIDER" = "gcp" ]; then
        if ! command_exists gcloud; then
            missing_tools+=("gcloud")
        fi
    else
        print_error "Invalid provider in config.yaml. Must be 'aws' or 'gcp'"
        exit 1
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install the missing tools and try again."
        exit 1
    fi
    
    print_success "All prerequisites satisfied"
}

# Function to validate cloud credentials
validate_credentials() {
    print_status "Validating cloud credentials..."
    
    if [ "$PROVIDER" = "aws" ]; then
        if ! aws sts get-caller-identity >/dev/null 2>&1; then
            print_error "AWS credentials not configured or invalid"
            print_error "Please run: aws configure"
            exit 1
        fi
        print_success "AWS credentials validated"
    elif [ "$PROVIDER" = "gcp" ]; then
        if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 >/dev/null 2>&1; then
            print_error "GCP credentials not configured or invalid"
            print_error "Please run: gcloud auth application-default login"
            exit 1
        fi
        print_success "GCP credentials validated"
    fi
}

# Function to initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    
    if terraform init; then
        print_success "Terraform initialized successfully"
    else
        print_error "Terraform initialization failed"
        exit 1
    fi
}

# Function to plan deployment
plan_deployment() {
    print_status "Planning Terraform deployment..."
    
    if terraform plan -out=tfplan; then
        print_success "Terraform plan completed successfully"
        
        echo
        print_warning "Please review the plan above carefully."
        read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
        echo
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Deployment cancelled by user"
            exit 0
        fi
    else
        print_error "Terraform plan failed"
        exit 1
    fi
}

# Function to apply deployment
apply_deployment() {
    print_status "Applying Terraform deployment..."
    
    if terraform apply tfplan; then
        print_success "Infrastructure deployed successfully"
    else
        print_error "Terraform apply failed"
        exit 1
    fi
}

# Function to configure kubectl
configure_kubectl() {
    print_status "Configuring kubectl..."
    
    CLUSTER_NAME=$(grep "^cluster_name:" config.yaml | awk '{print $2}' | tr -d '"')
    REGION=$(grep "^region:" config.yaml | awk '{print $2}' | tr -d '"')
    
    if [ "$PROVIDER" = "aws" ]; then
        if aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"; then
            print_success "kubectl configured for AWS EKS"
        else
            print_error "Failed to configure kubectl for AWS EKS"
            exit 1
        fi
    elif [ "$PROVIDER" = "gcp" ]; then
        PROJECT_ID=$(grep "^gcp_project_id:" config.yaml | awk '{print $2}' | tr -d '"')
        if gcloud container clusters get-credentials "$CLUSTER_NAME" --region "$REGION" --project "$PROJECT_ID"; then
            print_success "kubectl configured for GCP GKE"
        else
            print_error "Failed to configure kubectl for GCP GKE"
            exit 1
        fi
    fi
}

# Function to deploy initialization jobs
deploy_init_jobs() {
    print_status "Deploying initialization jobs..."
    
    # Wait for cluster to be ready
    print_status "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # Apply initialization jobs
    if kubectl apply -f jobs/; then
        print_success "Initialization jobs deployed"
        
        print_status "Waiting for jobs to complete..."
        
        # Wait for each job to complete
        local jobs=("init-secrets" "postgres-migration" "mongo-replica-sync" "weaviate-schema-setup" "redis-config-setup")
        
        for job in "${jobs[@]}"; do
            print_status "Waiting for job: $job"
            kubectl wait --for=condition=complete job/$job --timeout=600s || {
                print_warning "Job $job did not complete within timeout. Check logs:"
                print_warning "kubectl logs job/$job"
            }
        done
        
        print_success "All initialization jobs completed"
    else
        print_error "Failed to deploy initialization jobs"
        exit 1
    fi
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    echo
    print_status "Cluster nodes:"
    kubectl get nodes
    
    echo
    print_status "All pods:"
    kubectl get pods --all-namespaces
    
    echo
    print_status "Services:"
    kubectl get services
    
    echo
    print_status "Ingress:"
    kubectl get ingress
    
    echo
    print_status "Storage:"
    kubectl get pv,pvc
    
    echo
    print_success "Deployment verification completed"
}

# Function to display next steps
show_next_steps() {
    echo
    print_success "🎉 101GenAI Platform deployed successfully!"
    echo
    print_status "Next steps:"
    echo "1. Update secrets with actual values:"
    echo "   kubectl edit secret app-secrets"
    echo "   kubectl edit secret external-secrets"
    echo
    echo "2. Get ingress controller external IP:"
    echo "   kubectl get svc -n ingress-nginx"
    echo
    echo "3. Access your services:"
    echo "   - Frontend: http://<INGRESS_IP>/"
    echo "   - Backend API: http://<INGRESS_IP>/api/"
    echo "   - Keycloak: http://<INGRESS_IP>/auth/"
    echo
    echo "4. Monitor your deployment:"
    echo "   kubectl get pods --all-namespaces"
    echo "   kubectl logs -f deployment/backend-app"
    echo
    print_status "For troubleshooting, check the README.md file"
}

# Main deployment function
main() {
    echo "🚀 101GenAI Platform Deployment Script"
    echo "======================================"
    echo
    
    check_prerequisites
    validate_credentials
    init_terraform
    plan_deployment
    apply_deployment
    configure_kubectl
    deploy_init_jobs
    verify_deployment
    show_next_steps
}

# Handle script arguments
case "${1:-}" in
    "plan")
        check_prerequisites
        validate_credentials
        init_terraform
        terraform plan
        ;;
    "apply")
        check_prerequisites
        validate_credentials
        init_terraform
        terraform apply
        ;;
    "destroy")
        print_warning "This will destroy all infrastructure and data!"
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            terraform destroy
        else
            print_status "Destroy cancelled"
        fi
        ;;
    "verify")
        verify_deployment
        ;;
    *)
        main
        ;;
esac
