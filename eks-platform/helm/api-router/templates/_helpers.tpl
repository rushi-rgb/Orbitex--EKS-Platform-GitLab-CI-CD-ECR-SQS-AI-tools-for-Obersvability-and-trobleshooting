{{/*
Expand the name of the chart.
*/}}
{{- define "api-router.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "api-router.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "api-router.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{ include "api-router.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "api-router.selectorLabels" -}}
app.kubernetes.io/name: {{ include "api-router.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
