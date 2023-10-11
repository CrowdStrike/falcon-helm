{{/*
Expand the name of the chart.
*/}}
{{- define "cs-image-analyzer-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cs-image-analyzer-agent.fullname" -}}
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
{{- define "cs-image-analyzer-agent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cs-image-analyzer-agent.labels" -}}
helm.sh/chart: {{ include "cs-image-analyzer-agent.chart" . }}
{{ include "cs-image-analyzer-agent.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cs-image-analyzer-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cs-image-analyzer-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cs-image-analyzer-agent.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cs-image-analyzer-agent.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{- define "imagePullSecret" }}
{{- with .Values.crowdstrikeConfig }}
{{- if eq .env "us-gov-1" }}
{{- printf "{\"auths\":{\"registry.laggar.gcw.crowdstrike.com\":{\"username\":\"ia-%s\",\"password\":\"%s\",\"email\":\"image-assessment@crowdstrike.com\",\"auth\":\"%s\"}}}" .cid .dockerAPIToken (printf "ia-%s:%s" .cid .dockerAPIToken | b64enc) | b64enc }}
{{- else if eq .env "us-gov-2" }}
{{- printf "{\"auths\":{\"registry.us-gov-2.crowdstrike.com\":{\"username\":\"ia-%s\",\"password\":\"%s\",\"email\":\"image-assessment@crowdstrike.com\",\"auth\":\"%s\"}}}" .cid .dockerAPIToken (printf "ia-%s:%s" .cid .dockerAPIToken | b64enc) | b64enc }}
{{- else }}
{{- printf "{\"auths\":{\"registry.crowdstrike.com\":{\"username\":\"ia-%s\",\"password\":\"%s\",\"email\":\"image-assessment@crowdstrike.com\",\"auth\":\"%s\"}}}" .cid .dockerAPIToken (printf "ia-%s:%s" .cid .dockerAPIToken | b64enc) | b64enc }}
{{- end }}
{{- end }}
{{- end }}