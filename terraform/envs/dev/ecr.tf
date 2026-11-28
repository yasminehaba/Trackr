# Registres d'images sur AWS (remplacent GHCR pour EKS en phase T+)
resource "aws_ecr_repository" "app" {
  for_each = toset(["${var.project}-backend", "${var.project}-frontend"])

  name                 = each.key
  image_tag_mutability = "IMMUTABLE" # un tag sha-<7> ne peut jamais être réécrit
  force_delete         = true        # dev : terraform destroy supprime aussi les images

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }
}

# Ne garder que les 20 images les plus récentes : le stockage ECR est facturé
resource "aws_ecr_lifecycle_policy" "app" {
  for_each   = aws_ecr_repository.app
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Conserver les 20 images les plus récentes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}