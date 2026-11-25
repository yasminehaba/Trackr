{{/*
═══════════════════════════════════════════════════════════════════════════════
 Fonctions réutilisées par tous les templates (« named templates »).
 Appel : {{ include "trackr.xxx" <contexte> }}
═══════════════════════════════════════════════════════════════════════════════
*/}}

{{/* Préfixe des noms de ressources : le nom de la release (ex. « trackr »). */}}
{{- define "trackr.fullname" -}}
{{- .Release.Name | trunc 40 | trimSuffix "-" -}}
{{- end -}}

{{/* Nom d'un composant : <release>-<composant>, ex. trackr-backend. */}}
{{- define "trackr.componentName" -}}
{{- printf "%s-%s" (include "trackr.fullname" .root) .component -}}
{{- end -}}

{{/* Labels communs à toutes les ressources. Contexte : . (racine) */}}
{{- define "trackr.commonLabels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/part-of: trackr
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* Labels de sélection d'un composant (immuables). Contexte : dict "root" . "component" "backend" */}}
{{- define "trackr.selectorLabels" -}}
app.kubernetes.io/name: {{ include "trackr.componentName" . }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end -}}

{{/* Labels complets d'un composant. Contexte : dict "root" . "component" "backend" */}}
{{- define "trackr.labels" -}}
{{ include "trackr.commonLabels" .root }}
app.kubernetes.io/name: {{ include "trackr.componentName" . }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* Image d'un service applicatif. Échoue si le tag n'est pas fourni. */}}
{{- define "trackr.image" -}}
{{- $tag := required "image.tag est obligatoire (ex. --set image.tag=sha-xxxxxxx)" .root.Values.image.tag -}}
{{- printf "%s/trackr-%s:%s" .root.Values.image.registry .component $tag -}}
{{- end -}}

{{/* Origines CORS : URL publique + origines supplémentaires, séparées par des virgules. */}}
{{- define "trackr.corsOrigins" -}}
{{- prepend .Values.extraCorsOrigins .Values.publicUrl | join "," -}}
{{- end -}}

{{/* Contexte de sécurité commun aux conteneurs. */}}
{{- define "trackr.containerSecurityContext" -}}
allowPrivilegeEscalation: false
capabilities:
  drop: ["ALL"]
{{- end -}}