output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = local.provider == "aws" ? module.aws_infrastructure[0].cluster_endpoint : module.gcp_infrastructure[0].cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = local.cluster_name
}

output "region" {
  description = "Deployment region"
  value       = local.region
}

output "provider" {
  description = "Cloud provider used"
  value       = local.provider
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value = local.provider == "aws" ? 
    "aws eks update-kubeconfig --region ${local.region} --name ${local.cluster_name}" :
    "gcloud container clusters get-credentials ${local.cluster_name} --region ${local.region}"
}

output "storage_info" {
  description = "Storage configuration details"
  value = local.provider == "aws" ? {
    efs_id = module.aws_infrastructure[0].efs_id
    storage_class = "efs-sc"
  } : {
    filestore_instance = module.gcp_infrastructure[0].filestore_instance
    storage_class = "filestore-sc"
  }
}

output "service_endpoints" {
  description = "Service endpoints and access information"
  value = {
    ingress_controller = local.provider == "aws" ? module.aws_infrastructure[0].ingress_controller_endpoint : module.gcp_infrastructure[0].ingress_controller_endpoint
    services = {
      for service_name, service_config in local.services :
      service_name => {
        replicas = service_config.replicas
        resources = service_config.resources
      }
    }
  }
}
