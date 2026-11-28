provider "aws" {
  region = var.region

  # Étiquettes appliquées à TOUTES les ressources : suivi des coûts et nettoyage
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "yasminehaba/Trackr"
    }
  }
}