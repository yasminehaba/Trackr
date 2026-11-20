# Décisions d'architecture (ADR)

Chaque décision importante est notée ici avec son contexte et ses conséquences,
pour pouvoir la justifier plus tard (soutenance, entretien, nouveau membre de l'équipe).

---

## ADR-001 — Développer dans WSL 2 avec Docker Desktop

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Contexte :** la machine de développement est sous Windows 11. Les outils DevOps (Docker, kubectl, Minikube, Helm, Terraform) et les conteneurs sont Linux.
- **Décision :** travailler dans Ubuntu 24.04 sous WSL 2, avec le moteur de Docker Desktop via l'intégration WSL. Le code vit dans le système de fichiers Linux (`~`), pas sous `/mnt/c`.
- **Conséquences :** builds et volumes rapides, scripts shell en LF, commandes identiques à celles de la CI (Ubuntu). Il faut éviter les binaires Windows présents dans le PATH (`mvn`, `npm` sous `/mnt/c`).

## ADR-002 — Modèle de branches

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Décision :** `main` (stable, démontrable) ← `develop` (intégration) ← branches de travail `devops/*` et `feature/*`. Fusion uniquement par Pull Request.
- **Conséquences :** `main` reste toujours déployable ; chaque PR déclenchera la CI (phase D).

## ADR-003 — Authentification Git par clé SSH

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Contexte :** le push HTTPS avec un token a échoué (403, droits du token insuffisants).
- **Décision :** clé SSH ed25519 dédiée à la machine.
- **Conséquences :** pas de token à stocker ni à renouveler ; la clé privée ne quitte jamais la machine.

## ADR-004 — Exécuter builds et tests dans des conteneurs

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Contexte :** Java et Node ne sont pas installés dans WSL ; les versions Windows de Maven et npm sont dans le PATH.
- **Décision :** lancer Maven et Node via les images du projet (`docker compose run` / `exec`).
- **Conséquences :** mêmes versions qu'en CI et en production ; rien à installer localement.

## ADR-005 — Structure du dépôt créée au fil des phases

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Contexte :** la structure cible prévoit `k8s/`, `helm/`, `terraform/`, `monitoring/`, etc.
- **Décision :** ne pas créer de dossiers vides ; chaque dossier est créé dans la phase qui lui donne un contenu. Le code applicatif (`backend/`, `frontend/`) n'est pas déplacé.
- **Conséquences :** pas de fichiers `.gitkeep` inutiles ; la structure du dépôt reflète ce qui fonctionne réellement.

## ADR-006 — Normaliser les fins de ligne avec `.gitattributes`

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Contexte :** un script shell en CRLF échoue dans un conteneur Linux (`/bin/sh^M: not found`). `core.autocrlf` ne s'applique qu'à une machine.
- **Décision :** fichier `.gitattributes` versionné : LF par défaut, CRLF pour `*.cmd`/`*.bat`, binaires marqués.
- **Conséquences :** comportement identique pour tout contributeur, quel que soit son OS ou sa configuration Git.

## ADR-007 — Minikube avant AWS

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Décision :** valider entièrement le déploiement Kubernetes sur Minikube avant de créer toute ressource AWS payante.
- **Conséquences :** apprentissage et corrections gratuits ; les ressources AWS ne sont créées qu'après validation locale et accord explicite sur les coûts.

## ADR-008 — Conception de la CI GitHub Actions

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Décisions :**
  - Déclenchement sur push vers `main`/`develop` et sur Pull Request : les branches de travail sont testées via leur PR, sans exécution en double.
  - `permissions: contents: read` au niveau du workflow (moindre privilège).
  - Actions tierces épinglées par **SHA de commit** (avec la version en commentaire) : un tag peut être déplacé par un attaquant, un SHA non.
  - `mvnw verify` au lieu de `test` : compile, teste et produit le `.jar`.
  - Version de Node lue depuis `frontend/.nvmrc` : une seule source de vérité.
  - Scan Trivy (dépendances + secrets) en mode rapport : les vulnérabilités existantes seront traitées en phase M, puis le job deviendra bloquant.
  - Job `ci-status` unique pour la protection de branche.
- **Reporté :** analyse de qualité de code (SonarCloud) et couverture de tests, à évaluer en phase M.

## ADR-009 — Le frontend appelle l'API par un chemin relatif `/api`

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Contexte :** l'URL de l'API était écrite dans le bundle Angular au moment du build (`http://localhost:8080/api`). Une image construite pour un environnement ne fonctionnait pas dans un autre, ce qui empêche de déployer la même image (tag immuable) partout.
- **Décision :** l'image utilise `/api`. nginx, dans le même conteneur que le frontend, fait proxy vers le backend dont l'adresse est lue au démarrage (`BACKEND_URL`). En Kubernetes, l'Ingress pourra aussi router `/api` directement vers le backend.
- **Conséquences :** une seule image pour Compose, Minikube et EKS ; plus de CORS en production (même origine) ; le backend n'a plus besoin d'être exposé publiquement. Le déploiement Netlify d'origine garde son mécanisme `API_URL`.

## ADR-010 — Images de production durcies

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Décisions :**
  - Backend : runtime `eclipse-temurin:17-jre-alpine` (JRE seul, sans JDK ni Maven), utilisateur à UID numérique fixe `10001`.
  - Frontend : `nginxinc/nginx-unprivileged` (UID 101, port 8080) au lieu de `nginx` qui démarre en root.
  - `HEALTHCHECK` dans les deux images ; `-XX:MaxRAMPercentage=75` pour que la JVM respecte la limite mémoire du conteneur.
  - nginx écrase `X-Forwarded-For` avec l'IP qu'il voit : un client ne peut plus usurper une IP pour contourner le rate limiting.
- **Conséquences :** images plus petites, compatibles avec `runAsNonRoot` en Kubernetes (phase I) ; ports internes à 8080 pour les deux services.

## ADR-011 — Publication des images sur GHCR

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Contexte :** les images doivent être construites une fois, testées, puis déployées telles quelles (Minikube, puis EKS).
- **Décisions :**
  - Registre : GitHub Container Registry (`ghcr.io/<owner>/trackr-backend|frontend`), authentifié par le `GITHUB_TOKEN` du workflow (`packages: write` limité au job de publication) : aucun secret à créer.
  - Déclenchement par `workflow_run` après une CI **réussie** sur un **push** vers `main`/`develop` : le code d'une PR n'est jamais publié.
  - Le tag `sha-<7>` est immuable et c'est lui qu'on déploie ; `develop`, `main` et `latest` sont des tags mobiles de confort ; `X.Y.Z` pour les releases.
  - Un test de fumée s'exécute sur l'image construite avant tout push : une image qui ne démarre pas n'est jamais publiée.
- **Limite connue :** un tag `vX.Y.Z` est publié sans attendre la CI. Il doit être posé sur un commit de `main` déjà validé (procédure formalisée en phase G).

## ADR-012 — `develop` comme branche par défaut du fork

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Contexte :** GitHub ne déclenche un workflow `workflow_run` (et ne liste un workflow manuel) que s'il existe sur la branche par défaut. `publish.yml` n'existait que sur `develop`, la branche par défaut étant `main`.
- **Décision :** branche par défaut = `develop` (modèle git-flow). `main` ne reçoit que des versions stables.
- **Conséquences :** Publish se déclenche automatiquement après chaque CI verte ; les PR proposent `develop` comme base par défaut.

## ADR-013 — Stratégie de déploiement continu local

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Contexte :** les runners hébergés par GitHub ne peuvent pas joindre la machine locale (Docker Compose aujourd'hui, Minikube ensuite). Deux options : un runner auto-hébergé sur la machine, ou un déploiement déclenché localement.
- **Décision :** script de déploiement local (`scripts/deploy.sh`) qui *tire* une version déjà publiée. Pas de runner auto-hébergé.
- **Raisons :**
  - Le dépôt est un fork **public** : un runner auto-hébergé pourrait exécuter sur la machine personnelle du code venant d'une PR externe — GitHub déconseille explicitement ce montage.
  - Le modèle « pull » n'ouvre aucun port et ne donne à GitHub aucun accès à la machine.
  - Seules des versions publiées (donc testées par la CI et le test de fumée) sont déployables.
- **Conséquences :** *Continuous Delivery* en local (chaque commit sur `develop` produit une version déployable en une commande) ; *Continuous Deployment* complet sur AWS (phase Y), où GitHub Actions peut joindre EKS via OIDC. Le script sera étendu à Minikube (Helm) en phase L.

## ADR-014 — Kustomize (base + overlays) pour les manifests

- **Date :** 2026-11-20 · **Statut :** acceptée
- **Décision :** `k8s/base` contient les ressources communes ; chaque environnement est un overlay (`k8s/overlays/local`, plus tard `aws`). Kustomize est intégré à `kubectl`.
- **Conséquences :** pas de copie entre environnements ; secrets générés depuis des fichiers locaux ignorés par Git, avec un suffixe de hash qui redémarre les pods quand ils changent.

## ADR-015 — Sondes Kubernetes du backend

- **Date :** 2026-11-20 · **Statut :** acceptée
- **Décision :** groupes Actuator `liveness` et `readiness` activés ; seuls ces deux chemins sont publics et exclus du rate limiting. `readiness` inclut la base de données, `liveness` non.
- **Raison :** si PostgreSQL tombe, les pods backend sont retirés du trafic au lieu d'être redémarrés en boucle (un redémarrage ne réparerait pas la base).

## ADR-016 — PostgreSQL en StatefulSet sur Minikube

- **Date :** 2026-11-20 · **Statut :** acceptée
- **Décision :** en local, PostgreSQL tourne dans le cluster (StatefulSet + PVC). Sur AWS, il sera remplacé par RDS (phase X).

## ADR-017 — Migrations de schéma avec Flyway

- **Date :** 2026-11-20 · **Statut :** acceptée
- **Contexte :** Hibernate (`ddl-auto: update`) modifiait le schéma au démarrage : pas d'historique, pas de relecture, et des conflits si plusieurs pods démarrent sur une base vide (backend limité à 1 réplique).
- **Décision :** Flyway gère le schéma (`db/migration/V<n>__*.sql`) ; Hibernate passe en `validate`. V1 reproduit exactement le schéma existant (vérifié par comparaison `pg_dump` : 79 lignes de DDL identiques). `baseline-on-migrate` marque les bases existantes comme étant en V1.
- **Conséquences :** migrations relues en PR et testées par la CI (base vide → V1 → validation Hibernate) ; verrou Flyway lors des démarrages simultanés ; un fichier de migration appliqué ne se modifie jamais.