output "deployed_services" {
  description = "List of deployed services"
  value = [
    for service_name, _ in var.services : service_name
  ]
}

output "ingress_info" {
  description = "Ingress controller information"
  value = {
    name = "nginx-ingress"
    namespace = "ingress-nginx"
  }
}
