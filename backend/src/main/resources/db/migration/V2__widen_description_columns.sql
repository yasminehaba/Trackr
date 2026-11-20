-- ─────────────────────────────────────────────────────────────────────────────
-- V2 — Aligner la taille des descriptions sur la validation de l'API
--
-- ProjectRequest et TaskRequest acceptent jusqu'à 1000 caractères
-- (@Size(max = 1000)), mais les colonnes étaient limitées à 255 :
-- une description de 256 à 1000 caractères provoquait une erreur 500.
-- Élargir un VARCHAR ne réécrit pas la table : opération rapide et sans perte.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE projects ALTER COLUMN description TYPE VARCHAR(1000);
ALTER TABLE tasks    ALTER COLUMN description TYPE VARCHAR(1000);