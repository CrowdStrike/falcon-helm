{{- define "falcon-integration-gateway.backends" -}}
{{-   $aws                  := ternary "AWS"                "" .Values.push.aws_security_hub.enabled }}
{{-   $azure                := ternary "AZURE"              "" .Values.push.azure_log_analytics.enabled }}
{{-   $chronicle            := ternary "CHRONICLE"          "" .Values.push.chronicle.enabled }}
{{-   $cloudtrail_lake      := ternary "CLOUDTRAIL_LAKE"    "" .Values.push.cloudtrail_lake.enabled }}
{{-   $gcp                  := ternary "GCP"                "" .Values.push.gcp_security_command_center.enabled }}
{{-   $workspaceone         := ternary "WORKSPACEONE"       "" .Values.push.vmware_workspace_one.enabled }}
{{-   $backends             := list $aws $azure $chronicle $cloudtrail_lake $gcp $workspaceone | compact }}
{{-   $_ := first $backends | required "at least one push backend must be enabled" }}
{{-   join "," $backends }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "falcon-integration-gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "falcon-integration-gateway.fullname" -}}
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
{{- define "falcon-integration-gateway.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "falcon-integration-gateway.labels" -}}
helm.sh/chart: {{ include "falcon-integration-gateway.chart" . }}
{{ include "falcon-integration-gateway.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "falcon-integration-gateway.selectorLabels" -}}
app.kubernetes.io/name: {{ include "falcon-integration-gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "falcon-integration-gateway.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "falcon-integration-gateway.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
