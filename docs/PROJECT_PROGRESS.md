# Trackr DevOps — Suivi du projet

> Dernière mise à jour : 2026-11-19 · Branche de travail : `devops/foundation`

## Vue d'ensemble

| Phase | Intitulé | État |
|---|---|---|
| A | Fork et configuration du dépôt | ✅ Terminé |
| B | Audit de l'application | ✅ Terminé |
| C | Organisation du dépôt DevOps | ✅ Terminé |
| D | Intégration continue (GitHub Actions) | ✅ Terminé |
| E | Conteneurisation Docker | ✅ Terminé |
| F | Registre de conteneurs (GHCR) | ✅ Terminé |
| G | Déploiement continu | 🔄 En cours |
| H | Préparation de Minikube | ⏳ À faire |
| — | Préparation K8s (Flyway, sondes, métriques) | ⏳ À faire |
| I – L | Manifests, déploiement Minikube, K8s avancé, Helm | ⏳ À faire |
| M – O | DevSecOps, Terraform, Ansible | ⏳ À faire |
| P – S | Prometheus, Grafana, logs, tests de charge | ⏳ À faire |
| T – Z | AWS (dernière étape) | ⏳ À faire |

## Phase A — Fork et configuration du dépôt ✅

- Fork : `yasminehaba/Trackr` · `upstream` = `juandavidperez/Trackr`
- Clone dans le système de fichiers WSL (`~/devopsProject/Trackr`), pas sous `/mnt/c`
- Authentification GitHub par clé SSH (ed25519)
- Branches : `main` (stable), `develop` (intégration), `devops/foundation` (travail)
- `core.autocrlf=input` configuré

## Phase B — Audit de l'application ✅

### Résultats de validation (2026-11-19)

| Vérification | Résultat |
|---|---|
| Stack dev Docker Compose (db, backend, frontend) | ✅ 3 conteneurs démarrés, db *healthy* |
| `GET /api/health` (dev et prod) | ✅ `{"status":"UP"}` |
| Connexion `admin@trackr.dev` + Kanban (dev) | ✅ Fonctionnel |
| Tests backend (JUnit 5 + Mockito) | ✅ 126/126 — BUILD SUCCESS |
| Tests frontend (Vitest) | ✅ 101/101 — 18 fichiers |
| Image backend de production | ✅ Démarre et répond |
| Image frontend de production | ❌ Sert la page « Welcome to nginx! » |

## Phase C — Organisation du dépôt ✅

- `.gitattributes` : LF imposé (CRLF pour `*.cmd`/`*.bat`), binaires marqués — vérifié avec `git ls-files --eol`
- Documents de suivi : `PROJECT_PROGRESS.md`, `ARCHITECTURE.md`, `DECISIONS.md` (ADR-001 à 007)
- README : nombres de tests corrigés (126 backend, 101 frontend)
- Commit `754ae1e` sur `devops/foundation`

## Phase D — Intégration continue 🔄

- `ci.yml` réécrit : jobs `backend`, `frontend`, `security`, `ci-status`
- Déclencheurs : push sur `main`/`develop`, PR vers `main`/`develop`, lancement manuel
- Rapports JUnit publiés en artefacts + résumé dans l'onglet *Summary* (`scripts/ci/junit-summary.py`)

### Résultats de validation (2026-11-19)

| Exécution | Événement | Résultat |
|---|---|---|
| CI #1 | PR #1 ouverte | ✅ 4/4 jobs (backend 58 s, frontend 48 s) |
| CI #2 | Test volontairement cassé (`JwtTokenProviderTest`) | ❌ backend + CI status — échec détecté |
| CI #3 | Revert du test cassé | ✅ |
| CI #4 | Fusion de la PR #1 dans `develop` | ✅ |

## Phase E — Conteneurisation Docker ✅

- Frontend : nginx non-root (`nginx-unprivileged`, port 8080), page par défaut supprimée, `index.csr.html` renommé, proxy `/api` vers le backend, `/healthz`, en-têtes de sécurité
- Backend : runtime JRE seul (Temurin 17), UID fixe 10001, `HEALTHCHECK` sur `/actuator/health`, heap adapté au conteneur
- Compose : PostgreSQL 16 partout ; en prod, seul le frontend est publié (port 80)
- Config nginx testée avec le build Angular réel : `/`, `/login`, `/projects/3` → page Trackr ; `/api/*` → backend ; `X-Forwarded-For` usurpé remplacé

### Résultats de validation (2026-11-19, `docker-compose.prod.yml`)

| Test | Résultat |
|---|---|
| Taille des images | backend 370 Mo (568 Mo avant, −35 %) · frontend 82,6 Mo (94,7 Mo avant) |
| Utilisateurs | `uid=10001(trackr)` · `uid=101(nginx)` — aucun conteneur root |
| Page servie | `<title>Trackr</title>` — bug « Welcome to nginx! » corrigé |
| Route SPA `/projects/1` | 200 |
| `/healthz` · `/api/health` via nginx | `ok` · `{"status":"UP"}` |
| Backend non exposé (port 8080) | Connexion refusée ✅ |
| Inscription + connexion via `/api` | JWT reçu (même origine, sans CORS) |
| Création de projet authentifiée | `id 1` créé |
| Persistance après `down` / `up` | Projet retrouvé (volume `trackr_pgdata` conservé) |
| Démarrage ordonné | db healthy → backend healthy (≈ 22 s) → frontend |

## Phase F — Registre de conteneurs (GHCR) ✅

- Workflow `publish.yml` : après une CI verte sur `main`/`develop`, sur tag `vX.Y.Z` ou manuellement
- Build → test de fumée (backend avec PostgreSQL, frontend : page Trackr + route SPA, utilisateur non-root) → push
- Tags : `sha-<7>` (immuable), `develop`/`main`, `latest` (main), `X.Y.Z`/`X.Y` (release)
- `docker-compose.prod.yml` accepte `BACKEND_IMAGE` / `FRONTEND_IMAGE` pour lancer les images publiées
- Branche par défaut du fork passée à `develop` (condition pour `workflow_run`, ADR-012)

### Résultats de validation (2026-11-19)

| Test | Résultat |
|---|---|
| Publish (run 44535323193) | ✅ backend 3 min 55 s (test de fumée avec PostgreSQL) · frontend 1 min 44 s |
| Packages GHCR | `trackr-backend`, `trackr-frontend` — publics |
| `docker pull` sans identifiants | ✅ `sha-9482132` (backend `sha256:12c4b431…`, frontend `sha256:c5dd7a4f…`) |
| Stack lancée avec les images publiées (`--no-build`) | 3 conteneurs *healthy*, `<title>Trackr</title>`, API `UP` |
| Traçabilité | label `org.opencontainers.image.revision` = commit `948213298afd…` de `develop` |

## Phase G — Déploiement continu 🔄

- Stratégie : *Continuous Delivery* — la CI produit automatiquement des images testées ; le déploiement local est tiré par la machine (`scripts/deploy.sh`), rien n'est exposé (ADR-013)
- `scripts/deploy.sh` : vérifie la publication sur GHCR, déploie, attend les healthchecks, contrôle page + API + image en cours, revient automatiquement à la version précédente en cas d'échec ; `--rollback`, `--status`, historique dans `.deploy/`
- Script testé sur 10 scénarios simulés (succès, version non publiée, API cassée, conteneur unhealthy, retours arrière automatique et manuel, argument invalide)
- Validation à faire : déploiements réels successifs, échec simulé avec retour arrière, `--status`
## Phase K — Kubernetes avancé 🔄

### K1 — Migrations Flyway ✅
| Cas | Résultat (2026-11-20) |
|---|---|
| Base vide (CI) | V1 exécutée, Hibernate `validate` OK, 126 tests ✅ |
| Base existante (Minikube) | `Successfully baselined schema with version: 1` (type BASELINE) |
| Données | 1 utilisateur, 2 projets, 2 tâches avant et après |
| V2 (descriptions 1000 caractères) | Bug HTTP 500 reproduit, puis corrigé par migration |
## Problèmes connus

| # | Problème | Gravité | Phase prévue |
|---|---|---|---|
| 1 | L'image frontend prod sert `index.html` de nginx ; Angular produit `index.csr.html` | 🔴 | E — corrigé et validé |
| 2 | Aucune migration de base (`ddl-auto: update` en prod) | 🔴 | Avant I |
| 3 | URL de l'API figée au build : image non portable entre environnements | 🔴 | E — corrigé et validé (`/api` relatif) |
| 4 | Rate limiting en mémoire par pod ; `X-Forwarded-For` accepté sans contrôle | 🟠 | En-tête neutralisé par nginx (E) ; stockage partagé en M |
| 5 | Pas de sondes liveness/readiness ni de métriques Prometheus | 🟠 | Avant I |
| 6 | 12 vulnérabilités npm (1 critique, 7 élevées) | 🟠 | D / M |
| 7 | PostgreSQL 15 en Compose, 16 en CI | 🟡 | E — corrigé et validé |
| 8 | CI limitée à `main`, sans `permissions`, sans rapports, sans build | 🟡 | D |
| 9 | Swagger public en production | 🟡 | M |
| 10 | Spring Boot 3.2.5 n'est plus maintenu en open source | 🟡 | Hors périmètre (à documenter) |
| 11 | Le formulaire de connexion affiche « Invalid email or password » pour toute erreur sans champ `message` (429 du rate limiting, 403 CORS) | 🟡 | Hors périmètre DevOps (bug applicatif documenté) |
| 12 | Derrière un proxy/port-forward, plusieurs clients partagent la même IP pour le rate limiting | 🟠 | M |
| 13 | Flyway 9.22 (imposé par Spring Boot 3.2) non certifié pour PostgreSQL 16 — fonctionne, avertissement au démarrage | 🟡 | Mise à jour de Spring Boot (lié au n°10) |
| 14 | Descriptions > 255 caractères → HTTP 500 (validation API à 1000) | 🟠 | Résolu (migration V2) |

Problème local résolu : le port 8080 était occupé par le listener Oracle (`TNSLSNR`) sur la machine de développement ; Oracle a été arrêté.

## Prochaine action recommandée

Valider `scripts/deploy.sh` sur la machine locale (déploiement, échec simulé, retour arrière), puis passer à la phase H (Minikube).
## Phase I — Manifests Kubernetes ✅

- Kustomize : `k8s/base` + `k8s/overlays/local` (images GHCR, secrets générés, host `trackr.local`)
- PostgreSQL en StatefulSet + PVC 2 Gi ; backend 1 réplique ; frontend 2 répliques ; Ingress `/api` et `/`
- Pods durcis : non-root, lecture seule, capabilities retirées, seccomp, requests/limits
- Sondes backend liveness/readiness (readiness inclut la base) — CI 126/126 ✅ (PR #5)
- `kubectl kustomize` : 13 ressources · dry-run serveur sans erreur
### K2 — Scalabilité ✅
| Test | Résultat (2026-11-22) |
|---|---|
| 2 répliques backend | 2 pods Ready, 2 IP dans l'EndpointSlice (Flyway : démarrage simultané sans conflit) |
| `kubectl scale` frontend | 3 pods, puis retour à 2 par `kubectl apply -k` (Git = source de vérité) |
| `kubectl scale` backend à 1 | Annulé par le HPA : « below Spec.MinReplicas » → 2 |
| HPA | 2 → 4 (pic CPU au démarrage de la JVM) → 3 → 2 (« All metrics below target ») |
| Test de charge (busybox, 30 boucles sur `/api/health`) | CPU 1 % → 360 % → 2 puis 4 répliques (plafond) ; arrêt → 1 % → 3 → 2 après 2 min de stabilisation (`docs/k8s-hpa-loadtest.log`) |
### K3 — Cycle de vie et résilience ✅
| Test | Résultat (2026-11-22/23) |
|---|---|
| Rolling update frontend (`kubectl set image`) | Pod par pod ; ReplicaSet `5c9f6cf5bc` (version déjà connue) réutilisé |
| `rollout history` / `rollout undo` | Révisions 2-4 avec change-cause ; retour à `sha-c79d2d0` |
| Déploiement raté (image inexistante) | Nouveau pod `ErrImagePull`, les 2 anciens restent `1/1` ; `undo` répare ; `diff exit=0` |
| PostgreSQL arrêté | Pods backend démarrés : `0/1`, RESTARTS 0 (readiness) ; pods en démarrage : `CrashLoopBackOff` ; retour automatique après rétablissement |
| Arrêt complet du cluster | Redémarrages désordonnés (backend sans base, nginx sans DNS), puis convergence sans intervention |
| Dérive `replicas: 0` | `kubectl diff` : `0 → 1` ; restaurée par `kubectl apply -k` |
| Pod `postgres-0` supprimé | Recréé avec le même nom et le même PVC (`2d23h`) ; 3 projets intacts |

Leçons : un rollback d'urgence (`rollout undo`) ne remplace pas une correction dans Git ; les événements Kubernetes expirent au bout d'une heure (→ Prometheus en phase P).

## Phase J — Déploiement sur Minikube ✅

Version déployée : `sha-48c6c54` (2026-11-20) · Accès : `http://trackr.local:8088` (port-forward du contrôleur ingress-nginx)

| Étape | Résultat |
|---|---|
| Namespace, ConfigMap, Secrets | Créés ; secrets avec suffixe de hash |
| PostgreSQL | `postgres-0` 1/1, PVC `data-postgres-0` Bound 2 Gi |
| Backend | 1/1 Ready — readiness `UP` = connexion PostgreSQL validée |
| Frontend | 2/2 Ready |
| Services | `postgres` headless ; backend et frontend en ClusterIP (aucune IP externe) |
| Ingress | `/api` → backend, `/` → 2 pods frontend ; 404 sans le bon host |
| Cohérence | `kubectl diff -k` : aucune différence (exit 0) |
| Tests API | Connexion, projet, tâche, statut Kanban, dashboard |
| Tests navigateur | Inscription, connexion, projet, tâche, glisser-déposer persistant, dashboard |

Incident résolu : connexion refusée dans le navigateur (403) alors que `curl` réussissait. Cause : CORS — l'origine `http://trackr.local:8088` n'était pas autorisée (Spring Boot sur Kubernetes calcule son origine avec `X-Forwarded-Port: 80`). Correction : origine ajoutée dans l'overlay, puis `kubectl rollout restart` (variables d'environnement lues au démarrage).
