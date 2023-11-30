{{/*
Expand the name of the chart.
*/}}
{{- define "falcon-sensor.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "falcon-sensor.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "falcon-sensor.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "falcon-sensor.labels" -}}
helm.sh/chart: {{ include "falcon-sensor.chart" . }}
{{ include "falcon-sensor.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "falcon-sensor.selectorLabels" -}}
app.kubernetes.io/name: {{ include "falcon-sensor.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "falcon-sensor.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "falcon-sensor.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "falcon-sensor.image" -}}
{{- if .Values.node.enabled -}}
{{- if .Values.node.image.digest -}}
{{- if contains "sha256:" .Values.node.image.digest -}}
{{- printf "%s@%s" .Values.node.image.repository .Values.node.image.digest -}}
{{- else -}}
{{- printf "%s@%s:%s" .Values.node.image.repository "sha256" .Values.node.image.digest -}}
{{- end -}}
{{- else -}}
{{- printf "%s:%s" .Values.node.image.repository .Values.node.image.tag -}}
{{- end -}}
{{- else -}}
{{- if .Values.container.image.digest -}}
{{- if contains "sha256:" .Values.container.image.digest -}}
{{- printf "%s@%s" .Values.container.image.repository .Values.container.image.digest -}}
{{- else -}}
{{- printf "%s@%s:%s" .Values.container.image.repository "sha256" .Values.container.image.digest -}}
{{- end -}}
{{- else -}}
{{- printf "%s:%s" .Values.container.image.repository .Values.container.image.tag -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "falcon-sensor.priorityClassName" -}}
{{- printf "%s" .Values.node.daemonset.priorityClassName -}}
{{- if not .Values.node.daemonset.priorityClassName -}}
{{- printf "%s" "falcon-helm-node-security-critical" -}}
{{- end -}}
{{- end -}}

{{- define "falcon-sensor.daemonsetResources" -}}
{{- if .Values.node.gke.autopilot -}}
resources:
  {{- if (.Values.node.daemonset.resources | default dict ).limits }}
  limits:
    cpu: {{ (.Values.node.daemonset.resources.limits | default dict ).cpu | default "750m" }}
    memory: {{ (.Values.node.daemonset.resources.limits | default dict ).memory | default "1.5Gi" }}
    ephemeral-storage: {{  (index (.Values.node.daemonset.resources.limits | default dict ) "ephemeral-storage") |  default "100Mi" }}
  {{- else }}
  limits:
    cpu: 750m
    memory: 1.5Gi
    ephemeral-storage: 100Mi
  {{- end }}
  {{- if (.Values.node.daemonset.resources | default dict ).requests }}
  requests:
    cpu: {{ (.Values.node.daemonset.resources.requests | default dict ).cpu | default "750m" }}
    ephemeral-storage: {{  (index (.Values.node.daemonset.resources.requests | default dict ) "ephemeral-storage") |  default "100Mi" }}
    memory: {{ (.Values.node.daemonset.resources.requests | default dict ).memory | default "1.5Gi" }}
  {{- else }}
  requests:
    cpu: 750m
    memory: 1.5Gi
    ephemeral-storage: 100Mi
  {{- end }}
 {{- else -}}
{{- if .Values.node.daemonset.resources -}}
resources:
{{- toYaml .Values.node.daemonset.resources | trim | nindent 2 -}}
{{- end -}}
{{- end -}}
{{- end -}}
