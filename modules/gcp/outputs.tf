output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = "https://${google_container_cluster.main.endpoint}"
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.main.master_auth[0].cluster_ca_certificate
}

output "cluster_token" {
  description = "GKE cluster authentication token"
  value       = data.google_client_config.default.access_token
}

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.main.name
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.main.name
}

output "subnet_name" {
  description = "Subnet name"
  value       = google_compute_subnetwork.main.name
}

output "filestore_instance" {
  description = "Filestore instance details"
  value = {
    name        = google_filestore_instance.main.name
    ip_address  = google_filestore_instance.main.networks[0].ip_addresses[0]
    file_share  = google_filestore_instance.main.file_shares[0].name
  }
}

output "service_account_email" {
  description = "Service account email for workload identity"
  value       = google_service_account.workload_identity.email
}

output "ingress_controller_endpoint" {
  description = "Ingress controller endpoint (placeholder)"
  value       = "Will be available after ingress controller deployment"
}
