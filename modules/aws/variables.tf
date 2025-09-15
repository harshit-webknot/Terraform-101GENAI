variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "machine_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3a.xlarge"
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
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
