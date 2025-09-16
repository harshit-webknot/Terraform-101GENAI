terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

locals {
  config = yamldecode(file("config.yaml"))
  
  # Common variables
  cluster_name   = local.config.cluster_name
  region         = local.config.region
  cloud_provider = local.config.provider   # ✅ renamed
  
  # Node configuration
  nodes = local.config.nodes
  
  # Services configuration
  services = local.config.services
  
  # Domains configuration
  domains = local.config.domains
  
  # Tags
  common_tags = {
    Project     = "101GenAI"
    Environment = local.config.environment
    ManagedBy   = "Terraform"
  }
}

# AWS provider (always declared, selected only via module count)
provider "aws" {
  region = local.region
  default_tags {
    tags = local.common_tags
  }
}

# GCP provider (always declared, selected only via module count)
provider "google" {
  project = local.config.gcp_project_id
  region  = local.region
}

# AWS Infrastructure
module "aws_infrastructure" {
  count  = local.cloud_provider == "aws" ? 1 : 0
  source = "./modules/aws"

  providers = {
    aws     = aws
    kubectl = gavinbunney/kubectl
    tls     = tls
  }
  
  cluster_name  = local.cluster_name
  region        = local.region
  node_count    = local.nodes.node_count
  machine_type  = local.nodes.machine_type
  services      = local.services
  common_tags   = local.common_tags
}

# GCP Infrastructure
module "gcp_infrastructure" {
  count  = local.cloud_provider == "gcp" ? 1 : 0
  source = "./modules/gcp"

  providers = {
    google  = google
    kubectl = gavinbunney/kubectl
  }
  
  cluster_name  = local.cluster_name
  region        = local.region
  project_id    = local.config.gcp_project_id
  node_count    = local.nodes.node_count
  machine_type  = local.nodes.machine_type
  services      = local.services
  common_tags   = local.common_tags
}

# Kubernetes provider config
provider "kubernetes" {
  host                   = local.cloud_provider == "aws" ? module.aws_infrastructure[0].cluster_endpoint : module.gcp_infrastructure[0].cluster_endpoint
  cluster_ca_certificate = base64decode(local.cloud_provider == "aws" ? module.aws_infrastructure[0].cluster_ca_certificate : module.gcp_infrastructure[0].cluster_ca_certificate)
  token                  = local.cloud_provider == "aws" ? module.aws_infrastructure[0].cluster_token : module.gcp_infrastructure[0].cluster_token
}

provider "helm" {
  kubernetes {
    host                   = local.cloud_provider == "aws" ? module.aws_infrastructure[0].cluster_endpoint : module.gcp_infrastructure[0].cluster_endpoint
    cluster_ca_certificate = base64decode(local.cloud_provider == "aws" ? module.aws_infrastructure[0].cluster_ca_certificate : module.gcp_infrastructure[0].cluster_ca_certificate)
    token                  = local.cloud_provider == "aws" ? module.aws_infrastructure[0].cluster_token : module.gcp_infrastructure[0].cluster_token
  }
}

provider "kubectl" {
  host                   = local.cloud_provider == "aws" ? module.aws_infrastructure[0].cluster_endpoint : module.gcp_infrastructure[0].cluster_endpoint
  cluster_ca_certificate = base64decode(local.cloud_provider == "aws" ? module.aws_infrastructure[0].cluster_ca_certificate : module.gcp_infrastructure[0].cluster_ca_certificate)
  token                  = local.cloud_provider == "aws" ? module.aws_infrastructure[0].cluster_token : module.gcp_infrastructure[0].cluster_token
  load_config_file       = false
}

# Deploy services using Helm
module "workloads" {
  source = "./modules/workloads"
  
  services      = local.services
  domains       = local.domains
  cluster_name  = local.cluster_name
  cloud_provider = local.cloud_provider   # ✅ fixed

  providers = {
    kubectl = gavinbunney/kubectl
    helm    = helm
  }
  
  # Storage configuration
  storage_class = local.cloud_provider == "aws" ? "efs-sc" : "filestore-sc"
  
  depends_on = [
    module.aws_infrastructure,
    module.gcp_infrastructure
  ]
}
