variable "config_file" {
  description = "Path to the configuration YAML file"
  type        = string
  default     = "config.yaml"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
