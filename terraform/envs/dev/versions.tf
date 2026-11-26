terraform {
  # 1.10+ : verrouillage natif de l'état dans S3 (use_lockfile), sans DynamoDB
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.74" # 6.74 minimum, jamais de 7.x sans décision explicite
    }
  }

  # État distant dans S3, configuré en phase T (terraform init -backend-config=...).
  # En phase N : terraform init -backend=false (aucun accès AWS).
  backend "s3" {}
}