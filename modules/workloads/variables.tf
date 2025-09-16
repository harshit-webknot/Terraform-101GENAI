variable "services" {
  description = "Services configuration with credentials and environment variables"
  type = map(object({
    replicas = number
    resources = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    credentials = optional(object({
      username = string
      password = string
      database = optional(string)
    }))
    env = optional(map(string), {})
  }))
}

variable "domains" {
  description = "Domain mapping for services"
  type = object({
    frontend = string
    backend  = string
    keycloak = string
    weaviate = string
  })
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "provider" {
  description = "Cloud provider (aws or gcp)"
  type        = string
}

variable "storage_class" {
  description = "Storage class to use for persistent volumes"
  type        = string
  default     = "standard"
}
