module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.30.2"

  name               = local.name
  kubernetes_version = var.kubernetes_version

  # API publique limitée aux IP autorisées + accès privé depuis le VPC
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.api_allowed_cidrs
  endpoint_private_access      = true

  # Les 5 journaux du plan de contrôle (Trivy AWS-0038), conservés 7 jours
  enabled_log_types                      = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = 7

  # L'identité qui exécute terraform apply devient administratrice du cluster
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      before_compute = true # réseau des pods prêt avant l'arrivée des nœuds
    }
    eks-pod-identity-agent = {
      before_compute = true # droits AWS pour les pods, sans clé (ADR-026)
    }
  }
  # GitHub Actions peut déployer, mais uniquement dans le namespace trackr
  access_entries = {
    github_deploy = {
      principal_arn = aws_iam_role.github_deploy.arn
      policy_associations = {
        deploy = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = ["trackr"]
          }
        }
      }
    }
  }
  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      min_size       = 2
      max_size       = 3
      desired_size   = 2
    }
  }
}