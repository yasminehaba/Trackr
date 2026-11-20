-- ─────────────────────────────────────────────────────────────────────────────
-- V1 — Schéma initial de Trackr
--
-- Reproduit exactement le schéma créé jusqu'ici par Hibernate (ddl-auto: update),
-- extrait avec pg_dump depuis la base Minikube le 2026-11-20.
-- Les noms de contraintes générés par Hibernate sont conservés : les bases
-- existantes (marquées « baseline » en V1) et les nouvelles bases sont identiques.
--
-- Règle Flyway : un fichier de migration appliqué ne se modifie JAMAIS.
-- Tout changement de schéma = un nouveau fichier V2__..., V3__...
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE users (
    id          BIGSERIAL PRIMARY KEY,
    created_at  TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL,
    email       VARCHAR(255) NOT NULL,
    name        VARCHAR(255) NOT NULL,
    password    VARCHAR(255) NOT NULL,
    role        VARCHAR(255) NOT NULL,
    CONSTRAINT uk_6dotkott2kjsp8vw4d0m25fb7 UNIQUE (email),
    CONSTRAINT users_role_check CHECK (role IN ('ADMIN', 'MEMBER'))
);

CREATE TABLE projects (
    id           BIGSERIAL PRIMARY KEY,
    created_at   TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL,
    description  VARCHAR(255),
    name         VARCHAR(255) NOT NULL,
    owner_id     BIGINT NOT NULL,
    CONSTRAINT fkmueqy6cpcwpfl8gnnag4idjt9 FOREIGN KEY (owner_id) REFERENCES users (id)
);

-- Table d'association « membres d'un projet » (relation ManyToMany).
CREATE TABLE project_members (
    project_id  BIGINT NOT NULL,
    user_id     BIGINT NOT NULL,
    CONSTRAINT project_members_pkey PRIMARY KEY (project_id, user_id),
    CONSTRAINT fkdki1sp2homqsdcvqm9yrix31g FOREIGN KEY (project_id) REFERENCES projects (id),
    CONSTRAINT fkgul2el0qjk5lsvig3wgajwm77 FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE TABLE tasks (
    id           BIGSERIAL PRIMARY KEY,
    created_at   TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL,
    description  VARCHAR(255),
    due_date     DATE,
    "position"   INTEGER,
    priority     VARCHAR(255) NOT NULL,
    status       VARCHAR(255) NOT NULL,
    title        VARCHAR(255) NOT NULL,
    updated_at   TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL,
    assignee_id  BIGINT,
    project_id   BIGINT NOT NULL,
    CONSTRAINT tasks_priority_check CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH')),
    CONSTRAINT tasks_status_check CHECK (status IN ('TODO', 'IN_PROGRESS', 'DONE')),
    CONSTRAINT fkekr1dgiqktpyoip3qmp6lxsit FOREIGN KEY (assignee_id) REFERENCES users (id),
    CONSTRAINT fksfhn82y57i3k9uxww1s007acc FOREIGN KEY (project_id) REFERENCES projects (id)
);