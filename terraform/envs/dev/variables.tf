variable "project" {
  description = "Nom du projet, préfixe de toutes les ressources"
  type        = string
  default     = "trackr"
}

variable "environment" {
  description = "Nom de l'environnement"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment doit valoir dev, staging ou prod."
  }
}

variable "region" {
  description = "Région AWS"
  type        = string
}

variable "azs" {
  description = "Zones de disponibilité (au moins 2 : exigence d'EKS et de RDS)"
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "Au moins 2 zones de disponibilité sont nécessaires."
  }
}

variable "vpc_cidr" {
  description = "Plage d'adresses du VPC"
  type        = string
  default     = "10.0.0.0/16"
}