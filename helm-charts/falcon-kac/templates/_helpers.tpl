{{/*
Expand the name of the chart.
*/}}
{{- define "falcon-kac.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Set the webhook name
*/}}
{{- define "falcon-kac.webhookName" -}}
{{ printf "%s.crowdstrike.com" .Chart.Name }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "falcon-kac.fullname" -}}
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
{{- define "falcon-kac.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "falcon-kac.labels" -}}
{{ include "falcon-kac.selectorLabels" . }}
app.kubernetes.io/component: kac
app.kubernetes.io/name: {{ include "falcon-kac.name" . }}
crowdstrike.com/provider: crowdstrike
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "falcon-kac.chart" . }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "falcon-kac.selectorLabels" -}}
app: {{ include "falcon-kac.name" . }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "falcon-kac.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "falcon-kac.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "falcon-kac.image" -}}
{{- if .Values.image.digest -}}
{{- if contains "sha256:" .Values.image.digest -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- else -}}
{{- printf "%s@%s:%s" .Values.image.repository "sha256" .Values.image.digest -}}
{{- end -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}
{{- end -}}

{{/*
On Openshift lookup namespaces and print namespaces with prefix openshift
*/}}
{{- define "falcon-kac.openshiftNamespaces" -}}
{{- if .Capabilities.APIVersions.Has "security.openshift.io/v1" -}}
{{- range $index, $namespace := (lookup "v1" "Namespace" "" "").items -}}
{{- if hasPrefix "openshift" $namespace.metadata.name -}}
- {{ printf "%s\n" $namespace.metadata.name }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
