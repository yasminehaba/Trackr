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