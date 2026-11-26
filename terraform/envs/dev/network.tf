locals {
  name = "${var.project}-${var.environment}" # trackr-dev
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.9.0" # version exacte : un module peut changer ses paramètres entre versions

  name = local.name
  cidr = var.vpc_cidr
  azs  = var.azs

  # Plages calculées à partir du CIDR du VPC (10.0.0.0/16) :
  #   privés  /20 : 10.0.0.0, 10.0.16.0  -> nœuds EKS et pods (beaucoup d'IP)
  #   publics /24 : 10.0.48.0, 10.0.49.0 -> Load Balancer, NAT Gateway
  #   base    /24 : 10.0.52.0, 10.0.53.0 -> RDS, sans route vers Internet
  private_subnets  = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets   = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 8, i + 48)]
  database_subnets = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 8, i + 52)]

  create_database_subnet_group = true

  # Une seule NAT Gateway (et non une par zone) : environ 33 $/mois économisés.
  # Compromis accepté en dev : si sa zone tombe, les nœuds perdent l'accès sortant.
  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Indiquent au contrôleur de Load Balancer AWS où placer les équilibreurs
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}