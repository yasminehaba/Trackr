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



variable "kubernetes_version" {
  description = "Version de Kubernetes du cluster EKS (doit être en support standard)"
  type        = string
  default     = "1.36"
}

variable "node_instance_types" {
  description = "Types d'instances EC2 des nœuds"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "api_allowed_cidrs" {
  description = "Plages d'adresses autorisées à joindre l'API Kubernetes (ex. ton IP en /32)"
  type        = list(string)

  validation {
    condition     = length(var.api_allowed_cidrs) > 0 && !contains(var.api_allowed_cidrs, "0.0.0.0/0")
    error_message = "Au moins une plage, et jamais 0.0.0.0/0 (API ouverte à tout Internet)."
  }
}

variable "db_instance_class" {
  description = "Classe d'instance RDS"
  type        = string
  default     = "db.t4g.micro"
}

variable "github_repository" {
  description = "Dépôt GitHub autorisé à assumer le rôle de déploiement (owner/repo)"
  type        = string
  default     = "yasminehaba/Trackr"
}

variable "db_deletion_protection" {
  description = "Protection contre la suppression de RDS (à passer à false uniquement pour détruire l'environnement)"
  type        = bool
  default     = true
}