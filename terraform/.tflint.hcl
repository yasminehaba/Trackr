config {
  # N'analyse que nos fichiers, pas l'intérieur des modules du registre
  call_module_type = "local"
}

# Règles Terraform recommandées (incluses dans tflint, aucun téléchargement)
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}