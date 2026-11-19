#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy.sh — déploie une version publiée de Trackr sur l'environnement local
#             (docker-compose.prod.yml), vérifie sa santé et revient
#             automatiquement à la version précédente en cas d'échec.
#
# Usage :
#   scripts/deploy.sh latest          dernière version de origin/develop
#   scripts/deploy.sh <sha>           un commit précis (7 caractères ou plus)
#   scripts/deploy.sh --rollback      revenir à la version précédente
#   scripts/deploy.sh --status        afficher la version déployée
#
# Test d'échec (injection de panne, pour démontrer le retour arrière) :
#   DEPLOY_SIMULATE_FAILURE=1 scripts/deploy.sh latest
#
# Une version n'est déployable que si ses deux images existent sur GHCR, ce qui
# garantit qu'elle a passé la CI et le test de fumée (workflow Publish).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT_DIR/docker-compose.prod.yml}"
STATE_DIR="${STATE_DIR:-$ROOT_DIR/.deploy}"
BASE_URL="${BASE_URL:-http://localhost}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-180}"

# Propriétaire GHCR déduit de l'URL du dépôt (git@github.com:<owner>/Trackr.git).
OWNER="${REGISTRY_OWNER:-$(git -C "$ROOT_DIR" remote get-url origin | sed -E 's#.*github\.com[:/]([^/]+)/.*#\1#' | tr '[:upper:]' '[:lower:]')}"
BACKEND_REPO="ghcr.io/$OWNER/trackr-backend"
FRONTEND_REPO="ghcr.io/$OWNER/trackr-frontend"

log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
fail() { printf '[%s] ERREUR : %s\n' "$(date +%H:%M:%S)" "$*" >&2; }

compose() { docker compose -f "$COMPOSE_FILE" "$@"; }

current_version()  { cat "$STATE_DIR/current"  2>/dev/null || true; }
previous_version() { cat "$STATE_DIR/previous" 2>/dev/null || true; }

record() {  # record <évènement> <version> <résultat>
  mkdir -p "$STATE_DIR"
  printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$3" >> "$STATE_DIR/history.log"
}

resolve_version() {
  local target="$1"
  if [ "$target" = "latest" ]; then
    git -C "$ROOT_DIR" fetch --quiet origin develop
    git -C "$ROOT_DIR" rev-parse --short=7 origin/develop
  elif [[ "$target" =~ ^[0-9a-f]{7,40}$ ]]; then
    echo "${target:0:7}"
  else
    fail "version invalide : '$target' (attendu : latest, un SHA, --rollback ou --status)"
    exit 2
  fi
}

images_published() {
  local version="$1"
  docker manifest inspect "$BACKEND_REPO:sha-$version"  >/dev/null 2>&1 &&
  docker manifest inspect "$FRONTEND_REPO:sha-$version" >/dev/null 2>&1
}

health_check() {
  local version="$1" running
  # 1. L'application répond-elle correctement ?
  curl -fsS -m 5 "$BASE_URL/healthz" >/dev/null                         || { fail "frontend /healthz ne répond pas"; return 1; }
  curl -fsS -m 5 "$BASE_URL/" | grep -q '<title>Trackr</title>'         || { fail "la page servie n'est pas Trackr"; return 1; }
  curl -fsS -m 5 "$BASE_URL/api/health" | grep -q '"UP"'                || { fail "l'API n'est pas UP"; return 1; }
  # 2. Est-ce bien la version demandée qui tourne ?
  running="$(docker inspect -f '{{.Config.Image}}' trackr-backend 2>/dev/null || true)"
  [ "$running" = "$BACKEND_REPO:sha-$version" ]                          || { fail "image backend inattendue : $running"; return 1; }
  return 0
}

# Injection de panne volontaire (uniquement pour la version cible, jamais pour le retour arrière).
simulated_failure() {
  if [ "${DEPLOY_SIMULATE_FAILURE:-0}" = "1" ] && [ "$1" = "deploy" ]; then
    fail "échec simulé (DEPLOY_SIMULATE_FAILURE=1)"
    return 0
  fi
  return 1
}

# start <version> : démarre la version et attend que tous les conteneurs soient healthy.
start() {
  local version="$1"
  export BACKEND_IMAGE="$BACKEND_REPO:sha-$version"
  export FRONTEND_IMAGE="$FRONTEND_REPO:sha-$version"
  log "Téléchargement des images sha-$version"
  compose pull --quiet backend frontend
  log "Démarrage (attente des healthchecks, $HEALTH_TIMEOUT s max)"
  compose up -d --no-build --wait --wait-timeout "$HEALTH_TIMEOUT"
}

deploy() {
  local version="$1" mode="${2:-deploy}" before
  before="$(current_version)"

  if [ "$mode" = "deploy" ] && [ "$version" = "$before" ]; then
    log "La version sha-$version est déjà déployée : rien à faire."
    return 0
  fi

  log "Vérification de la publication de sha-$version sur GHCR"
  if ! images_published "$version"; then
    fail "les images sha-$version n'existent pas sur GHCR (CI en échec ou Publish pas encore terminé)"
    record "$mode" "$version" "refusé"
    return 1
  fi

  if start "$version" && health_check "$version" && ! simulated_failure "$mode"; then
    mkdir -p "$STATE_DIR"
    if [ -n "$before" ] && [ "$before" != "$version" ]; then echo "$before" > "$STATE_DIR/previous"; fi
    echo "$version" > "$STATE_DIR/current"
    record "$mode" "$version" "succès"
    log "✅ sha-$version déployée et en bonne santé ($BASE_URL)"
    return 0
  fi

  fail "le déploiement de sha-$version a échoué"
  compose logs --tail 30 backend frontend >&2 || true
  record "$mode" "$version" "échec"

  if [ "$mode" = "deploy" ] && [ -n "$before" ]; then
    log "↩️  Retour automatique à la version précédente sha-$before"
    if start "$before" && health_check "$before"; then
      record "rollback-auto" "$before" "succès"
      log "Version sha-$before restaurée."
    else
      record "rollback-auto" "$before" "échec"
      fail "le retour arrière a aussi échoué : intervention manuelle nécessaire"
    fi
  fi
  return 1
}

main() {
  local arg="${1:-}"
  local prev
  case "$arg" in
    --status)
      echo "Version déployée   : $(current_version)"
      echo "Version précédente : $(previous_version)"
      echo "Historique :"; tail -n 10 "$STATE_DIR/history.log" 2>/dev/null || echo "  (vide)"
      ;;
    --rollback)
      prev="$(previous_version)"
      [ -n "$prev" ] || { fail "aucune version précédente enregistrée"; exit 1; }
      deploy "$prev" rollback || exit 1
      ;;
    ""|-h|--help)
      sed -n '3,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      ;;
    *)
      local version
      version="$(resolve_version "$arg")" || exit 2
      deploy "$version"
      ;;
  esac
}

main "$@"
