output "vpc_id" {
  description = "Identifiant du VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Sous-réseaux privés (nœuds EKS)"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Sous-réseaux publics (Load Balancer)"
  value       = module.vpc.public_subnets
}

output "database_subnet_group" {
  description = "Groupe de sous-réseaux de RDS"
  value       = module.vpc.database_subnet_group_name
}


output "cluster_name" {
  description = "Nom du cluster EKS (aws eks update-kubeconfig --name ...)"
  value       = module.eks.cluster_name
}

output "ecr_repository_urls" {
  description = "URL des dépôts ECR"
  value       = { for k, r in aws_ecr_repository.app : k => r.repository_url }
}

output "rds_endpoint" {
  description = "Adresse de la base PostgreSQL (accessible seulement depuis le VPC)"
  value       = module.rds.db_instance_address
}

output "rds_master_secret_arn" {
  description = "ARN du secret Secrets Manager contenant le mot de passe (pas le mot de passe)"
  value       = module.rds.db_instance_master_user_secret_arn
}

output "github_deploy_role_arn" {
  description = "Rôle à indiquer dans le workflow GitHub (aws-actions/configure-aws-credentials)"
  value       = aws_iam_role.github_deploy.arn
}