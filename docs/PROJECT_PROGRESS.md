# Trackr DevOps — Suivi du projet

> Dernière mise à jour : 2026-11-25 · Branche d'intégration : `develop` (travail sur branches `devops/*`, `security/*`, `docs/*` + Pull Request)

## Vue d'ensemble

| Phase | Intitulé | État |
|---|---|---|
| A | Fork et configuration du dépôt | ✅ Terminé |
| B | Audit de l'application | ✅ Terminé |
| C | Organisation du dépôt DevOps | ✅ Terminé |
| D | Intégration continue (GitHub Actions) | ✅ Terminé |
| E | Conteneurisation Docker | ✅ Terminé |
| F | Registre de conteneurs (GHCR) | ✅ Terminé |
| G | Déploiement continu (local, modèle pull) | ✅ Terminé |
| H | Préparation de Minikube | ✅ Terminé |
| I | Manifests Kubernetes (Kustomize) | ✅ Terminé |
| J | Déploiement sur Minikube | ✅ Terminé |
| K | Kubernetes avancé (Flyway, HPA, résilience, RBAC) | ✅ Terminé |
| L | Helm | ✅ Terminé |
| M | DevSecOps | 🔄 En cours (M1–M3b ✅, M4 à faire) |
| N – O | Terraform, Ansible | ⏳ À faire |
| P – S | Prometheus, Grafana, logs, tests de charge | ⏳ À faire |
| T – Z | AWS (dernière étape) | ⏳ À faire |

## Phase A — Fork et configuration du dépôt ✅

- Fork : `yasminehaba/Trackr` · `upstream` = `juandavidperez/Trackr`
- Clone dans le système de fichiers WSL (`~/devopsProject/Trackr`), pas sous `/mnt/c`
- Authentification GitHub par clé SSH (ed25519)
- Branches : `main` (stable), `develop` (intégration, branche par défaut), branches de travail + PR
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
| Image frontend de production | ❌ Sert la page « Welcome to nginx! » (corrigé en phase E) |

## Phase C — Organisation du dépôt ✅

- `.gitattributes` : LF imposé (CRLF pour `*.cmd`/`*.bat`), binaires marqués — vérifié avec `git ls-files --eol`
- Documents de suivi : `PROJECT_PROGRESS.md`, `ARCHITECTURE.md`, `DECISIONS.md`
- README : nombres de tests corrigés (126 backend, 101 frontend)
- Commit `754ae1e`

## Phase D — Intégration continue ✅

- `ci.yml` réécrit : jobs `backend`, `frontend`, `security`, `helm` (ajouté en L), `ci-status`
- Déclencheurs : push sur `main`/`develop`, PR vers `main`/`develop`, lancement manuel
- Rapports JUnit publiés en artefacts + résumé dans l'onglet *Summary* (`scripts/ci/junit-summary.py`)
- Actions épinglées par SHA, `permissions: contents: read`

### Résultats de validation (2026-11-19)

| Exécution | Événement | Résultat |
|---|---|---|
| CI #1 | PR #1 ouverte | ✅ 4/4 jobs (backend 58 s, frontend 48 s) |
| CI #2 | Test volontairement cassé (`JwtTokenProviderTest`) | ❌ backend + CI status — échec détecté |
| CI #3 | Revert du test cassé | ✅ |
| CI #4 | Fusion de la PR #1 dans `develop` | ✅ |

## Phase E — Conteneurisation Docker ✅

- Frontend : nginx non-root (`nginx-unprivileged`, port 8080), page par défaut supprimée, `index.csr.html` renommé, proxy `/api` vers le backend (`BACKEND_URL`), `/healthz`, en-têtes de sécurité
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
- Build → test de fumée (backend avec PostgreSQL, frontend : page Trackr + route SPA, utilisateur non-root) → scan Trivy (ajouté en M) → push
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

## Phase G — Déploiement continu ✅

- Stratégie : *Continuous Delivery* — la CI produit automatiquement des images testées ; le déploiement local est tiré par la machine (`scripts/deploy.sh`), rien n'est exposé (ADR-013)
- `scripts/deploy.sh` : vérifie la publication sur GHCR, déploie, attend les healthchecks, contrôle page + API + image en cours, revient automatiquement à la version précédente en cas d'échec ; options `latest`, `<sha>`, `--rollback`, `--status` ; historique dans `.deploy/` (ignoré par Git)
- Script testé sur 10 scénarios simulés (succès, version non publiée, API cassée, conteneur unhealthy, retours arrière automatique et manuel, argument invalide)
- Validé sur la machine locale : déploiements réels successifs, échec simulé (`DEPLOY_SIMULATE_FAILURE=1`) avec retour arrière automatique, `--status`
- Sur Kubernetes, le même modèle « pull » est appliqué avec `helm upgrade --install --atomic` (phase L)

## Phase H — Préparation de Minikube ✅

- Cluster Minikube existant réutilisé (il héberge aussi le namespace `voting-app`)
- Addons `ingress` (ingress-nginx) et `metrics-server` activés
- Accès local uniquement : port-forward du contrôleur Ingress sur le port 8088, aucune exposition publique

## Phase I — Manifests Kubernetes ✅

- Kustomize : `k8s/base` + `k8s/overlays/local` (images GHCR, secrets générés depuis des fichiers ignorés par Git, host `trackr.local`)
- PostgreSQL en StatefulSet + PVC 2 Gi ; backend (2 à 4 répliques via le HPA, K2) ; frontend 2 répliques ; Ingress `/api` et `/`
- Pods durcis : non-root, système de fichiers en lecture seule, capabilities retirées, seccomp, requests/limits
- Sondes backend startup/liveness/readiness (readiness inclut la base) — CI 126/126 ✅ (PR #5)
- `kubectl kustomize` : 13 ressources · dry-run serveur sans erreur

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

## Phase K — Kubernetes avancé ✅

### K1 — Migrations Flyway ✅

| Cas | Résultat (2026-11-20) |
|---|---|
| Base vide (CI) | V1 exécutée, Hibernate `validate` OK, 126 tests ✅ |
| Base existante (Minikube) | `Successfully baselined schema with version: 1` (type BASELINE) |
| Données | 1 utilisateur, 2 projets, 2 tâches avant et après |
| V2 (descriptions 1000 caractères) | Bug HTTP 500 reproduit, puis corrigé par migration |

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

### K4 — RBAC et NetworkPolicies ✅

| Test | Résultat (2026-11-23) |
|---|---|
| RBAC viewer | list pods/deployments/logs : yes · secrets, delete, patch : no · autre namespace : no |
| RBAC deployer | patch deployments : yes · create/delete deployments, secrets : no |
| Refus réel | `get secrets --as=trackr-viewer` → Forbidden |
| NetworkPolicies | 4 politiques acceptées par l'API ; non appliquées par le CNI de Minikube (test `nc` depuis voting-app : open) — voir ADR-020 |

## Phase L — Helm ✅

Chart `helm/trackr` 0.1.0 · release `trackr` dans le namespace `trackr-helm` · accès `http://trackr-helm.localhost:8088`

| Test | Résultat (2026-11-25) |
|---|---|
| `helm lint` / `helm template` | 0 échec · 21 ressources · rendu refusé sans `image.tag` (vérifié aussi en CI, job `helm`) |
| Installation (`--wait`) | Révision 1 : tous les pods 1/1, Ingress, HPA, 4 NetworkPolicies |
| Cohabitation | `trackr.local` (Kustomize) et `trackr-helm.localhost` (Helm) servis par le même contrôleur Ingress |
| Upgrade de configuration | `jwtAccessExpiration` → ConfigMap modifiée, pods backend recréés automatiquement (checksum) ; diff des manifestes : 2 lignes |
| Rollback | Révision 4 « Rollback to 2 » ; ReplicaSet de la révision 2 réutilisé |
| Upgrade raté + `--atomic` | Révision 5 `failed` → révision 6 « Rollback to 4 » automatique ; API toujours UP |

## Phase M — DevSecOps 🔄

### M1 — Scan bloquant et correction des dépendances ✅

| Vérification | Résultat (2026-11-25) |
|---|---|
| Scan Trivy du dépôt (dépendances + secrets, HIGH/CRITICAL corrigeables) | Bloquant : le job `security` fait échouer `ci-status` |
| Frontend | `npm update` (npm 11) : 61 → 16 vulnérabilités, **0 HIGH/CRITICAL** ; 101 tests ✅ |
| Backend | pgjdbc → 42.7.12 (CVE-2026-42198, CVE-2026-54291) |
| Exceptions | `.trivyignore` : justification + date d'expiration obligatoires (ADR-022) |

### M2 — Scan des images et Dependabot ✅

| Vérification | Résultat |
|---|---|
| Publish | Scan Trivy de chaque image après le test de fumée, avant le push (ADR-023) |
| Dependabot | Maven, npm (groupe Angular), Docker, GitHub Actions ; hebdomadaire ; versions majeures exclues ; labels créés |

### M3 — Spring Boot 3.2.5 → 3.5.16 (PR #15) ✅

| Vérification | Résultat |
|---|---|
| Vulnérabilités Spring Security / Framework | 9 (dont 3 critiques) → corrigées |
| Dépendances alignées | `flyway-database-postgresql`, springdoc 2.8.14 |
| CI | 126 tests backend ✅, 5 checks ✅ |

### M3b — Images sans vulnérabilité HIGH/CRITICAL corrigeable (PR #16) ✅

| Vérification | Preuve | Statut |
|---|---|---|
| Couches Alpine | `apk upgrade` dans les deux Dockerfiles : 57 → 0 | ✅ |
| Jar backend | Jackson 2.21.7, Tomcat 10.1.59 : 11 CVE corrigées | ✅ |
| Exceptions | CVE-2026-47884 et CVE-2026-47890 (spring-webmvc, non exploitables, expirent le 2027-02-28) | ✅ |
| Publish | Scan Trivy des images ✅, push GHCR `sha-24866e1` | ✅ |
| Déploiement Helm | Révision 7 : Spring Boot 3.5.16, PostgreSQL 16.16 sans avertissement Flyway, 2 migrations validées | ✅ |
| Fonctionnel | Health UP, inscription et login 200 | ✅ |

### M4 — Durcissement final ⏳

- Secret scanning et push protection GitHub
- Swagger (`/v3/api-docs`, `/swagger-ui.html`) désactivé en prod
- `spring.jpa.open-in-view: false` ; suppression de `hibernate.dialect` explicite
- Job `actionlint` dans la CI (erreur YAML de `publish.yml` détectée trop tard)
- Stratégie de gestion des secrets pour AWS

## Problèmes connus

| # | Problème | Gravité | État |
|---|---|---|---|
| 1 | L'image frontend prod sert `index.html` de nginx ; Angular produit `index.csr.html` | 🔴 | ✅ Corrigé (E) |
| 2 | Aucune migration de base (`ddl-auto: update` en prod) | 🔴 | ✅ Corrigé (Flyway, K1) |
| 3 | URL de l'API figée au build : image non portable entre environnements | 🔴 | ✅ Corrigé (`/api` relatif, E) |
| 4 | Rate limiting en mémoire par pod ; `X-Forwarded-For` accepté sans contrôle | 🟠 | En-tête neutralisé par nginx (E) ; stockage partagé (Redis) encore à faire |
| 5 | Pas de sondes liveness/readiness ni de métriques Prometheus | 🟠 | Sondes ✅ (I) ; métriques en phase P |
| 6 | 12 vulnérabilités npm (1 critique, 7 élevées) | 🟠 | ✅ 0 HIGH/CRITICAL (M1) ; 16 modérées acceptées (outillage de build, ADR-022) |
| 7 | PostgreSQL 15 en Compose, 16 en CI | 🟡 | ✅ Corrigé (E) |
| 8 | CI limitée à `main`, sans `permissions`, sans rapports, sans build | 🟡 | ✅ Corrigé (D) |
| 9 | Swagger public en production | 🟡 | M4 |
| 10 | Spring Boot hors support open source | 🟡 | 3.5.16 (M3), dernière version OSS 3.x ; migration vers 4.x = chantier applicatif hors périmètre |
| 11 | Le formulaire de connexion affiche « Invalid email or password » pour toute erreur sans champ `message` (429, 403 CORS) ; le backend renvoie aussi **400** (et non 401) pour des identifiants invalides | 🟡 | Bug applicatif documenté, hors périmètre DevOps |
| 12 | Derrière un proxy/port-forward, plusieurs clients partagent la même IP pour le rate limiting | 🟠 | Ouvert (lié au n°4) |
| 13 | Flyway 9.22 non certifié pour PostgreSQL 16 — avertissement au démarrage | 🟡 | ✅ Corrigé (Flyway 11 via Spring Boot 3.5, M3) |
| 14 | Descriptions > 255 caractères → HTTP 500 (validation API à 1000) | 🟠 | ✅ Corrigé (migration V2, K1) |
| 15 | Avertissements au démarrage : `open-in-view` actif, `hibernate.dialect` superflu | 🟡 | M4 |
| 16 | NetworkPolicies non appliquées par le CNI de Minikube | 🟡 | Documenté (ADR-020) ; appliquées sur EKS (phase W) |

Problème local résolu : le port 8080 était occupé par le listener Oracle (`TNSLSNR`) sur la machine de développement ; Oracle a été arrêté.

## Prochaine action recommandée

Phase M4 : désactiver Swagger et `open-in-view` en prod, ajouter `actionlint` à la CI, activer le secret scanning et la push protection, puis clôturer la phase M.