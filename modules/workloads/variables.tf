variable "services" {
  description = "Services configuration"
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
    storage = optional(object({
      size         = string
      access_modes = list(string)
    }))
  }))
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
}
