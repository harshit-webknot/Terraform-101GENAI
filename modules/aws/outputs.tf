output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "EKS cluster CA certificate"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_token" {
  description = "EKS cluster authentication token"
  value       = data.aws_eks_cluster_auth.main.token
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "efs_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.main.id
}

output "efs_dns_name" {
  description = "EFS DNS name"
  value       = aws_efs_file_system.main.dns_name
}

output "node_group_arn" {
  description = "EKS node group ARN"
  value       = aws_eks_node_group.main.arn
}

output "ingress_controller_endpoint" {
  description = "Ingress controller endpoint (placeholder)"
  value       = "Will be available after ingress controller deployment"
}

# Data source for cluster auth
data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}
