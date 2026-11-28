# Décisions d'architecture (ADR)

Chaque décision importante est notée ici avec son contexte et ses conséquences,
pour pouvoir la justifier plus tard (soutenance, entretien, nouveau membre de l'équipe).
Une décision n'est jamais effacée : si elle change, elle est marquée « remplacée » et renvoie vers la nouvelle.

---

## ADR-001 — Développer dans WSL 2 avec Docker Desktop

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Contexte :** la machine de développement est sous Windows 11. Les outils DevOps (Docker, kubectl, Minikube, Helm, Terraform) et les conteneurs sont Linux.
- **Décision :** travailler dans Ubuntu 24.04 sous WSL 2, avec le moteur de Docker Desktop via l'intégration WSL. Le code vit dans le système de fichiers Linux (`~`), pas sous `/mnt/c`.
- **Conséquences :** builds et volumes rapides, scripts shell en LF, commandes identiques à celles de la CI (Ubuntu). Il faut éviter les binaires Windows présents dans le PATH (`mvn`, `npm` sous `/mnt/c`).

## ADR-002 — Modèle de branches

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Décision :** `main` (stable, démontrable) ← `develop` (intégration) ← branches de travail (`devops/*`, `feature/*`, `security/*`, `fix/*`, `docs/*`). Fusion uniquement par Pull Request.
- **Conséquences :** `main` reste toujours déployable ; chaque PR déclenche la CI.

## ADR-003 — Authentification Git par clé SSH

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Contexte :** le push HTTPS avec un token a échoué (403, droits du token insuffisants).
- **Décision :** clé SSH ed25519 dédiée à la machine.
- **Conséquences :** pas de token à stocker ni à renouveler ; la clé privée ne quitte jamais la machine.

## ADR-004 — Exécuter builds et tests dans des conteneurs

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Contexte :** Java et Node ne sont pas installés dans WSL ; les versions Windows de Maven et npm sont dans le PATH.
- **Décision :** lancer Maven et Node via des images Docker (`docker compose run` / `exec`, ou `docker run` avec l'image officielle).
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

- **Date :** 2026-11-19 · **Statut :** acceptée (scan Trivy : remplacé par ADR-022)
- **Décisions :**
  - Déclenchement sur push vers `main`/`develop` et sur Pull Request : les branches de travail sont testées via leur PR, sans exécution en double.
  - `permissions: contents: read` au niveau du workflow (moindre privilège).
  - Actions tierces épinglées par **SHA de commit** (avec la version en commentaire) : un tag peut être déplacé par un attaquant, un SHA non.
  - `mvnw verify` au lieu de `test` : compile, teste et produit le `.jar`.
  - Version de Node lue depuis `frontend/.nvmrc` : une seule source de vérité.
  - Scan Trivy (dépendances + secrets) d'abord en mode rapport ; **devenu bloquant en phase M (ADR-022)**.
  - Job `ci-status` unique pour la protection de branche ; il agrège `backend`, `frontend`, `security` et `helm` (ajouté en phase L, ADR-021).
- **Reporté :** analyse de qualité de code (SonarCloud) et couverture de tests ; validation des workflows (`actionlint`) prévue en M4.

## ADR-009 — Le frontend appelle l'API par un chemin relatif `/api`

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Contexte :** l'URL de l'API était écrite dans le bundle Angular au moment du build (`http://localhost:8080/api`). Une image construite pour un environnement ne fonctionnait pas dans un autre, ce qui empêche de déployer la même image (tag immuable) partout.
- **Décision :** l'image utilise `/api`. nginx, dans le même conteneur que le frontend, fait proxy vers le backend dont l'adresse est lue au démarrage (`BACKEND_URL`). En Kubernetes, l'Ingress route `/api` directement vers le backend.
- **Conséquences :** une seule image pour Compose, Minikube et EKS ; plus de CORS en production (même origine) ; le backend n'a plus besoin d'être exposé publiquement. Le déploiement Netlify d'origine garde son mécanisme `API_URL`.

## ADR-010 — Images de production durcies

- **Date :** 2026-11-19 · **Statut :** acceptée (complétée par ADR-023 : `apk upgrade`)
- **Décisions :**
  - Backend : runtime `eclipse-temurin:17-jre-alpine` (JRE seul, sans JDK ni Maven), utilisateur à UID numérique fixe `10001`.
  - Frontend : `nginxinc/nginx-unprivileged` (UID 101, port 8080) au lieu de `nginx` qui démarre en root.
  - `HEALTHCHECK` dans les deux images ; `-XX:MaxRAMPercentage=75` pour que la JVM respecte la limite mémoire du conteneur.
  - nginx écrase `X-Forwarded-For` avec l'IP qu'il voit : un client ne peut plus usurper une IP pour contourner le rate limiting.
- **Conséquences :** images plus petites, compatibles avec `runAsNonRoot` en Kubernetes ; ports internes à 8080 pour les deux services.

## ADR-011 — Publication des images sur GHCR

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Contexte :** les images doivent être construites une fois, testées, puis déployées telles quelles (Minikube, puis EKS).
- **Décisions :**
  - Registre : GitHub Container Registry (`ghcr.io/<owner>/trackr-backend|frontend`), authentifié par le `GITHUB_TOKEN` du workflow (`packages: write` limité au job de publication) : aucun secret à créer.
  - Déclenchement par `workflow_run` après une CI **réussie** sur un **push** vers `main`/`develop` : le code d'une PR n'est jamais publié.
  - Le tag `sha-<7>` est immuable et c'est lui qu'on déploie ; `develop`, `main` et `latest` sont des tags mobiles de confort ; `X.Y.Z` pour les releases.
  - Un test de fumée puis un scan Trivy (ADR-023) s'exécutent sur l'image construite avant tout push : une image qui ne démarre pas ou qui est vulnérable n'est jamais publiée.
- **Limite connue :** un tag `vX.Y.Z` est publié sans attendre la CI. Il doit être posé sur un commit de `main` déjà validé.

## ADR-012 — `develop` comme branche par défaut du fork

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Contexte :** GitHub ne déclenche un workflow `workflow_run` (et ne liste un workflow manuel) que s'il existe sur la branche par défaut. `publish.yml` n'existait que sur `develop`, la branche par défaut étant `main`.
- **Décision :** branche par défaut = `develop` (modèle git-flow). `main` ne reçoit que des versions stables.
- **Conséquences :** Publish se déclenche automatiquement après chaque CI verte ; les PR proposent `develop` comme base par défaut.

## ADR-013 — Stratégie de déploiement continu local

- **Date :** 2026-11-19 · **Statut :** acceptée
- **Contexte :** les runners hébergés par GitHub ne peuvent pas joindre la machine locale (Docker Compose, puis Minikube). Deux options : un runner auto-hébergé sur la machine, ou un déploiement déclenché localement.
- **Décision :** déploiement local qui *tire* une version déjà publiée. Pas de runner auto-hébergé.
- **Raisons :**
  - Le dépôt est un fork **public** : un runner auto-hébergé pourrait exécuter sur la machine personnelle du code venant d'une PR externe — GitHub déconseille explicitement ce montage.
  - Le modèle « pull » n'ouvre aucun port et ne donne à GitHub aucun accès à la machine.
  - Seules des versions publiées (donc testées par la CI, le test de fumée et le scan d'image) sont déployables.
- **Mise en œuvre :** Docker Compose → `scripts/deploy.sh` (health checks, retour arrière automatique) ; Minikube → `helm upgrade --install --set image.tag=sha-<7> --wait --atomic` (ADR-021), qui apporte les mêmes garanties.
- **Conséquences :** *Continuous Delivery* en local (chaque commit sur `develop` produit une version déployable en une commande) ; *Continuous Deployment* complet sur AWS (phase Y), où GitHub Actions peut joindre EKS via OIDC.

## ADR-014 — Kustomize (base + overlays) pour les manifests

- **Date :** 2026-11-20 · **Statut :** acceptée (remplacée par Helm pour les nouveaux déploiements, ADR-021)
- **Décision :** `k8s/base` contient les ressources communes ; chaque environnement est un overlay (`k8s/overlays/local`). Kustomize est intégré à `kubectl`.
- **Conséquences :** pas de copie entre environnements ; secrets générés depuis des fichiers locaux ignorés par Git, avec un suffixe de hash qui redémarre les pods quand ils changent.

## ADR-015 — Sondes Kubernetes du backend

- **Date :** 2026-11-20 · **Statut :** acceptée
- **Décision :** groupes Actuator `liveness` et `readiness` activés ; seuls `/actuator/health`, `/actuator/health/liveness` et `/actuator/health/readiness` sont publics et exclus du rate limiting. `readiness` inclut la base de données, `liveness` non. Une `startupProbe` couvre le démarrage lent de la JVM.
- **Raison :** si PostgreSQL tombe, les pods backend sont retirés du trafic au lieu d'être redémarrés en boucle (un redémarrage ne réparerait pas la base). Vérifié en K3.

## ADR-016 — PostgreSQL en StatefulSet sur Minikube

- **Date :** 2026-11-20 · **Statut :** acceptée
- **Décision :** en local, PostgreSQL tourne dans le cluster (StatefulSet + PVC). Sur AWS, il sera remplacé par RDS (phase X).

## ADR-017 — Migrations de schéma avec Flyway

- **Date :** 2026-11-20 · **Statut :** acceptée
- **Contexte :** Hibernate (`ddl-auto: update`) modifiait le schéma au démarrage : pas d'historique, pas de relecture, et des conflits si plusieurs pods démarrent sur une base vide (backend limité alors à 1 réplique).
- **Décision :** Flyway gère le schéma (`db/migration/V<n>__*.sql`) ; Hibernate passe en `validate`. V1 reproduit exactement le schéma existant (vérifié par comparaison `pg_dump` : 79 lignes de DDL identiques). `baseline-on-migrate` marque les bases existantes comme étant en V1. V2 élargit les descriptions à 1000 caractères.
- **Conséquences :** migrations relues en PR et testées par la CI (base vide → V1 → V2 → validation Hibernate) ; verrou Flyway lors des démarrages simultanés ; un fichier de migration appliqué ne se modifie jamais.

## ADR-018 — Autoscaling horizontal du backend (HPA)

- **Date :** 2026-11-22 · **Statut :** acceptée
- **Décision :** HPA `autoscaling/v2` sur le CPU (cible 70 % de la request 250m), entre 2 et 4 répliques ; montée immédiate (+2 pods/30 s), descente prudente (2 min de stabilisation, −1 pod/min). Le Deployment ne fixe plus `replicas`.
- **Observation :** au démarrage, la JVM consomme beaucoup de CPU (classes, JIT, Hibernate, Flyway) : le HPA est monté à 4 répliques sans trafic, puis redescendu à 2. Pistes si nécessaire : fenêtre de stabilisation en montée, request CPU ajustée, métriques applicatives (Prometheus, phase P).
- **Limite :** rate limiting en mémoire par pod (problème connu n°4).

## ADR-019 — RBAC à privilèges minimaux

- **Date :** 2026-11-23 · **Statut :** acceptée
- **Décision :** deux ServiceAccounts limités au namespace de l'application : `trackr-viewer` (lecture seule) et `trackr-deployer` (modification des Deployments, sans création ni suppression). Aucun accès aux Secrets. Repris dans le chart Helm (`rbac.roles`).
- **Vérification :** `kubectl auth can-i --as=system:serviceaccount:trackr:...` et refus réel (`Forbidden`) sur `get secrets`.

## ADR-020 — NetworkPolicies écrites mais non appliquées sur Minikube

- **Date :** 2026-11-23 · **Statut :** acceptée
- **Contexte :** le CNI par défaut du cluster Minikube existant n'applique pas les NetworkPolicies. Les tester demanderait un cluster avec Calico (nouveau profil ou recréation du cluster).
- **Décision :** modèle « tout refuser puis autoriser » (Ingress → frontend/backend, frontend → backend, backend → PostgreSQL), versionné dans `k8s/base` et dans le chart Helm, appliqué sur EKS (phase W). Non démontré localement.
- **Preuve de la limite :** un pod de `voting-app` atteint `postgres:5432` malgré la règle (`nc` : open).
- **À faire :** autoriser le namespace `monitoring` (phase P) ; restreindre le trafic sortant (egress).

## ADR-021 — Helm pour déployer Trackr

- **Date :** 2026-11-25 · **Statut :** acceptée
- **Contexte :** les manifests Kustomize (phases I–K) fonctionnent, mais n'ont ni historique de déploiement ni retour arrière global, et chaque paramètre demande un patch.
- **Décision :** chart `helm/trackr` (21 ressources) : images, configuration, autoscaling, RBAC et NetworkPolicies paramétrés par `values.yaml` ; un fichier de values par environnement. Les Secrets restent créés hors du chart (référencés par nom). Le chart est vérifié en CI (`helm lint`, `helm template`, garde-fou `image.tag`).
- **Conséquences :**
  - Helm devient la méthode de déploiement de référence (Minikube, puis EKS et la CD en phase Y). `helm upgrade --install --wait --atomic` : idempotent, avec retour arrière automatique.
  - L'annotation `checksum/config` redémarre les pods quand la configuration change.
  - Les manifests `k8s/` restent comme trace des phases I–K et ne seront plus enrichis ; le namespace `trackr` (Kustomize) pourra être supprimé pour libérer des ressources.

## ADR-022 — Scan de sécurité bloquant et exceptions documentées

- **Date :** 2026-11-25 · **Statut :** acceptée
- **Décision :** le scan Trivy du dépôt (dépendances HIGH/CRITICAL corrigeables + secrets) fait échouer la CI. Une exception n'est possible que dans `.trivyignore`, avec justification et date d'expiration.
- **Corrections :** frontend — `npm update` (npm 11) : 61 → 16 vulnérabilités, 0 HIGH/CRITICAL, 101 tests OK ; backend — pgjdbc → 42.7.12 (CVE-2026-42198, CVE-2026-54291).
- **Exceptions :** la première (CVE-2026-22733, Actuator Cloud Foundry) a été **retirée** après la montée en Spring Boot 3.5.16, qui la corrige. Exceptions en vigueur : voir ADR-024.
- **Risques acceptés :** 16 vulnérabilités modérées dans l'outillage de build Angular (CLI), absentes de l'image de production ; correctif = Angular 22.

## ADR-023 — Scan des images et mises à jour automatiques

- **Date :** 2026-11-25 · **Statut :** acceptée
- **Décision :** le workflow Publish scanne chaque image avec Trivy (OS + bibliothèques, HIGH/CRITICAL corrigeables) après le test de fumée et avant le push : une image vulnérable n'est jamais publiée. Dependabot propose chaque semaine des PR pour Maven, npm, Docker et GitHub Actions ; les versions majeures des frameworks sont exclues.
- **Raison :** le scan du code source ne voit pas les paquets du système de l'image (OpenSSL, musl…) ni les dépendances réellement embarquées dans le jar. Une faille publiée après une correction (cas vécu : pgjdbc 42.7.11 → 42.7.12) impose des mises à jour continues.
- **Images de base :** `apk upgrade --no-cache` dans l'étape runtime des deux Dockerfiles (57 → 0 vulnérabilités Alpine sur le frontend) : les images de base publiées sont souvent en retard sur les correctifs Alpine.
- **Cache de build :** l'étape finale (`AS runtime`) n'est jamais mise en cache (`no-cache-filters: runtime`, `pull: true`) : `apk upgrade` intègre toujours les derniers correctifs Alpine, et le cache reste actif pour npm et Maven. Constaté le 2026-11-28 : une faille corrigée après le 25/11 restait dans la couche en cache ; le scan d'image a bloqué la publication, et une reconstruction sans cache donnait 0 faille.

## ADR-024 — Montée de version Spring Boot 3.2.5 → 3.5.16

- **Date :** 2026-11-25 · **Statut :** acceptée
- **Contexte :** le scan bloquant a révélé 9 vulnérabilités (3 critiques) dans Spring Security 6.2.4 et Spring Framework 6.1.6, apportés par Spring Boot 3.2.5 (hors support).
- **Décision :** Spring Boot 3.5.16 (dernière version OSS de la génération 3.x), qui embarque Spring Framework 6.2.19 et Flyway 11. Dépendances alignées : `flyway-database-postgresql` (Flyway 10+), springdoc 2.8.14.
- **Surcharges de versions (scan du jar dans l'image) :** Jackson 2.21.7 (5 CVE HIGH), Tomcat 10.1.59 (5 CRITICAL, 1 HIGH), PostgreSQL JDBC 42.7.12. Le scan du `pom.xml` seul ne les voyait pas : seul le scan de l'artefact final montre les dépendances transitives réellement embarquées.
- **Exceptions :** CVE-2026-47884 (XsltView) et CVE-2026-47890 (SSE avec fragments de vue), corrigées seulement en Spring Framework 7 ; non exploitables (API REST, ni vue ni SSE). Expirent le 2027-02-28.
- **Validation :** CI 126 tests ✅ ; Publish (scan d'image) ✅ ; déploiement Helm révision 7 (`sha-24866e1`) : Flyway valide 2 migrations sans avertissement PostgreSQL 16, inscription et connexion fonctionnelles.
- **Dette :** la génération 3.5 n'est plus maintenue en open source ; la migration vers Spring Boot 4 (Spring Framework 7) est un chantier applicatif hors périmètre DevOps (problème connu n°10). Elle supprimera les deux exceptions.

## ADR-025 — Protections du dépôt GitHub

- **Date :** 2026-11-25 · **Statut :** acceptée
- **Décisions :**
  - Secret scanning et push protection activés : un token reconnu (GitHub, AWS…) est refusé **avant** d'entrer dans l'historique. Trivy (scanner `secret`) reste un second filet en CI.
  - `develop` et `main` protégées : fusion uniquement si `CI status` est vert, règle appliquée aussi à l'administrateur, force-push et suppression interdits. Pas de relecture obligatoire (projet mené seul).
- **Preuve :** push direct refusé (`GH006`, « Required status check "CI status" is expected »).
- **Conséquences :** toute modification, y compris la documentation, passe par une PR. Un incident comme celui de la phase C (revert accidentel corrigé par `push --force`) devient impossible sur les branches partagées.

## ADR-026 — Gestion des secrets jusqu'à AWS

- **Date :** 2026-11-25 · **Statut :** acceptée
- **Aujourd'hui :** aucun secret dans Git. En local, `.env` et `k8s/overlays/*/*.env` sont ignorés par Git ; les Secrets Kubernetes sont créés hors du chart Helm et référencés par nom. La CI n'utilise que le `GITHUB_TOKEN` éphémère.
- **Sur AWS (phases T–Z) :**
  - GitHub Actions → AWS par **OIDC** (rôle IAM assumé, jetons de quelques minutes) : aucune clé d'accès AWS stockée dans GitHub.
  - Mot de passe RDS généré et géré par **AWS Secrets Manager**, jamais écrit dans Terraform ni dans les values Helm.
  - Secrets injectés dans EKS par **External Secrets Operator** (rôle IAM du pod via IRSA), qui crée les Secrets Kubernetes attendus par le chart : le chart ne change pas.
  - État Terraform chiffré (backend S3), car il peut contenir des valeurs sensibles.
- **Règle :** aucune clé AWS n'est collée dans une conversation, un fichier versionné ou un log.

## ADR-027 — Infrastructure AWS en Terraform

- **Date :** 2026-11-27 · **Statut :** acceptée
- **Décisions :**
  - Modules communautaires `terraform-aws-modules` (VPC, EKS, RDS) épinglés à une version **exacte** ; provider AWS `~> 6.74` ; fichier de verrouillage versionné et imposé en CI (`-lockfile=readonly`).
  - Validation sans compte AWS : `fmt`, `validate` (`-backend=false`), tflint, Trivy config. `plan` et `apply` en phase T seulement, après accord sur les coûts.
  - État distant prévu dans S3 chiffré avec verrouillage natif (`use_lockfile`, Terraform ≥ 1.10) ; jamais dans Git.
  - Choix d'économie assumés pour la démo : une seule NAT Gateway, RDS mono-AZ, petites instances, journaux conservés 7 jours.
  - Valeurs personnelles (IP autorisée) dans `*.local.tfvars`, ignorés par Git.
- **Exceptions de sécurité** (`terraform/.trivyignore`, expirent le 2027-02-28) : AWS-0040 (API EKS publique, restreinte à des /32 + IAM) et AWS-0104 (sortie Internet des nœuds, via NAT et Flow Logs ; VPC Endpoints jugés trop coûteux).
- **Procédure de destruction :** `terraform apply -var db_deletion_protection=false`, puis `terraform destroy`. La protection empêche une suppression accidentelle de la base.