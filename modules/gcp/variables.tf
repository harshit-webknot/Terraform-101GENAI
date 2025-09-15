variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "machine_type" {
  description = "GCE machine type for worker nodes"
  type        = string
  default     = "e2-standard-4"
}

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

variable "common_tags" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default     = {}
}
