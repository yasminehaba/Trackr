# Groupe de sécurité de la base : seul le port 5432, seulement depuis les nœuds EKS
resource "aws_security_group" "rds" {
  name        = "${local.name}-rds"
  description = "PostgreSQL accessible uniquement depuis les noeuds EKS"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_nodes" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL depuis les noeuds EKS (pods backend)"
  referenced_security_group_id = module.eks.node_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "7.2.2"

  identifier = "${local.name}-postgres"

  engine               = "postgres"
  engine_version       = "16"
  family               = "postgres16"
  major_engine_version = "16"
  instance_class       = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 50 # croissance automatique plafonnée
  storage_encrypted     = true

  db_name  = "trackr"
  username = "trackr"
  port     = 5432

  # Mot de passe généré et stocké par AWS Secrets Manager (jamais dans Terraform)
  manage_master_user_password = true

  multi_az               = false
  publicly_accessible    = false
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]

  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]

  backup_retention_period = 7
  deletion_protection     = var.db_deletion_protection # false uniquement juste avant un destroy  skip_final_snapshot     = true

  create_db_option_group = false # inutile pour PostgreSQL
}

