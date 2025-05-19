{{/*
Expand the name of the chart.
*/}}
{{- define "ra-self-hosted.name" -}}
{{- default "shra" .Values.nameOverride | trunc 40 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ra-self-hosted.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 40 | trimSuffix "-" }}
{{- else -}}
{{- $name := default "shra" .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 40 | trimSuffix "-" }}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 50 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "ra-self-hosted-executor.fullname" -}}
{{- printf "%s-%s" (include "ra-self-hosted.fullname" .) "executor" | trunc 52 | trimSuffix "-" }}
{{- end -}}

{{- define "ra-self-hosted-executor.pullsecret-name" -}}
{{- printf "%s-%s-pullsecret" (include "ra-self-hosted.fullname" .) "executor" | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "ra-self-hosted-job-controller.fullname" -}}
{{- printf "%s-%s" (include "ra-self-hosted.fullname" .) "job-controller" | trunc 52 | trimSuffix "-" }}
{{- end -}}

{{- define "ra-self-hosted-job-controller.pullsecret-name" -}}
{{- printf "%s-%s-pullsecret" (include "ra-self-hosted.fullname" .) "job-controller" | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "ra-self-hosted.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ra-self-hosted.labels-executor" -}}
helm.sh/chart: {{ include "ra-self-hosted.chart" . }}
{{ include "ra-self-hosted-executor.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.executor.labels }}
{{ .Values.executor.labels }}
{{- end }}
{{- end }}

{{- define "ra-self-hosted-job-controller.labels" -}}
helm.sh/chart: {{ include "ra-self-hosted.chart" . }}
{{ include "ra-self-hosted-job-controller.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.jobController.labels }}
{{ .Values.jobController.labels }}
{{- end }}
{{- end }}

{{- define "ra-self-hosted.labels" -}}
helm.sh/chart: {{ include "ra-self-hosted.chart" . }}
{{ include "ra-self-hosted.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.jobController.labels }}
{{ .Values.jobController.labels }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ra-self-hosted-executor.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ra-self-hosted.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: executor
{{- end }}

{{- define "ra-self-hosted-job-controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ra-self-hosted.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: job-controller
{{- end }}

{{- define "ra-self-hosted.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ra-self-hosted.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "ra-self-hosted-executor.imageRegistry" -}}
{{- .Values.executor.image.registry -}}
{{- end -}}

{{- define "ra-self-hosted-executor.imageRepo" -}}
{{- .Values.executor.image.repository -}}
{{- end -}}


{{- define "ra-self-hosted-executor.image" -}}
{{- if .Values.executor.image.digest -}}
{{- if contains "sha256:" .Values.executor.image.digest -}}
{{- printf "%s/%s@%s" (include "ra-self-hosted-executor.imageRegistry" .) (include "ra-self-hosted-executor.imageRepo" .) .Values.executor.image.digest -}}
{{- else -}}
{{- printf "%s/%s@%s" (include "ra-self-hosted-executor.imageRegistry" .) (include "ra-self-hosted-executor.imageRepo" .) "sha256" .Values.executor.image.digest -}}
{{- end -}}
{{- else -}}
{{- printf "%s/%s:%s" (include "ra-self-hosted-executor.imageRegistry" .) (include "ra-self-hosted-executor.imageRepo" .) .Values.executor.image.tag -}}
{{- end -}}
{{- end -}}

{{- define "ra-self-hosted-job-controller.imageRegistry" -}}
{{- .Values.jobController.image.registry -}}
{{- end -}}

{{- define "ra-self-hosted-job-controller.imageRepo" -}}
{{- .Values.jobController.image.repository -}}
{{- end -}}


{{- define "ra-self-hosted-job-controller.image" -}}
{{- if .Values.jobController.image.digest -}}
{{- if contains "sha256:" .Values.jobController.image.digest -}}
{{- printf "%s/%s@%s" (include "ra-self-hosted-job-controller.imageRegistry" .) (include "ra-self-hosted-job-controller.imageRepo" .) .Values.jobController.image.digest -}}
{{- else -}}
{{- printf "%s/%s@%s" (include "ra-self-hosted-job-controller.imageRegistry" .) (include "ra-self-hosted-job-controller.imageRepo" .) "sha256" .Values.jobController.image.digest -}}
{{- end -}}
{{- else -}}
{{- printf "%s/%s:%s" (include "ra-self-hosted-job-controller.imageRegistry" .) (include "ra-self-hosted-job-controller.imageRepo" .) .Values.jobController.image.tag -}}
{{- end -}}
{{- end -}}

{{- define "ra-self-hosted-job-controller.db-pvc-name" -}}
{{- if .Values.jobController.dbStorage.create -}} {{- printf "%s-%s" (include "ra-self-hosted-job-controller.fullname" .) "db" | trunc 63 -}} {{- else -}} {{ .Values.jobController.dbStorage.existingClaimName }} {{- end -}}
{{- end -}}

{{- define "ra-self-hosted-executor.db-pvc-name" -}}
{{- if .Values.executor.dbStorage.create -}} {{- printf "%s-%s" (include "ra-self-hosted-executor.fullname" .) "db" | trunc 63 -}} {{- else -}} {{ .Values.executor.dbStorage.existingClaimName }} {{- end -}}
{{- end -}}

{{- define "ra-self-hosted-executor.storage-pvc-name" -}}
{{- if .Values.executor.assessmentStorage.pvc.create -}} {{- printf "%s-%s" (include "ra-self-hosted-executor.fullname" .) "storage" | trunc 63 -}} {{- else -}} {{ .Values.executor.assessmentStorage.pvc.existingClaimName }} {{- end -}}
{{- end -}}

{{- define "ra-self-hosted-executor.registry-credentials-json" -}}
{{- $creds := list -}}
{{- range $k, $v := .Values.registryConfigs -}}
{{- $cred := dict -}}
{{- $cred = set $cred "registry_type" $v.type -}}
{{- $cred = set $cred "registry_host" $v.host -}}
{{- $cred = set $cred "registry_port" $v.port -}}
{{- $cred = set $cred "credential_type" $v.credential_type -}}
{{- $credDetails := dict -}}
{{- $credsDict := (include "yamlToJson" $v.credentials | fromYaml )}}
{{- $credString := ($credsDict | toString)}}
{{- $credDetails = set $credDetails "details" $credsDict -}}
{{- $cred = set $cred "credential" $credDetails -}}
{{- $cred = set $cred "registry_id" (sha256sum (printf "%v:%v:%v" $v.host $v.port $credString)) -}}
{{- $creds = append $creds $cred }}
{{- end -}}
{{ toPrettyJson $creds }}
{{- end -}}

{{- define "ra-self-hosted-job-controller.job-configs-json" -}}
{{- $jobs := list -}}
{{- $heartBeatJob := dict }}
{{- $heartBeatJob = set $heartBeatJob "type" "agent_heartbeat" -}}
{{- $heartBeatJob = set $heartBeatJob "cron_schedule" "*/5 * * * *" -}}
{{- $jobs = append $jobs $heartBeatJob -}}
{{- range $k, $v := .Values.registryConfigs -}}
{{- $job := dict -}}
{{- $job = set $job "type" "registry_collection" -}}
{{- $job = set $job "cron_schedule" $v.cronSchedule -}}
{{- $props := dict -}}
{{- $props = set $props "registry_host" $v.host -}}
{{- $props = set $props "registry_port" $v.port -}}
{{- $props = set $props "registry_type" $v.type -}}
{{- $credsDict := (include "yamlToJson" $v.credentials | fromYaml )}}
{{- $credString := ($credsDict | toString)}}
{{- $props = set $props "registry_allowed_repositories" $v.allowedRepositories -}}
{{- $props = set $props "registry_id" (sha256sum (printf "%v:%v:%v" $v.host $v.port $credString)) -}}
{{- $job = set $job "properties" $props -}}
{{- $jobs = append $jobs $job -}}
{{- end -}}
{{- toPrettyJson $jobs -}}
{{- end -}}

{{- define "ra-self-hosted-job-controller.job-type-configs-json" -}}
{{- $configs := list -}}
{{- range $k, $v := .Values.crowdstrikeConfig.jobTypeConfigs -}}
{{- $configs = append $configs (set (include "yamlToJson" $v | fromYaml) "name" (snakecase $k)) -}}
{{- end -}}
{{- $heartBeatConfig := dict }}
{{- $heartBeatConfig = set $heartBeatConfig "name" "agent_heartbeat" -}}
{{- $heartBeatConfig = set $heartBeatConfig "threads_per_pod" 1 -}}
{{- $configs = append $configs $heartBeatConfig -}}
{{- toPrettyJson $configs -}}
{{- end -}}

{{- define "yamlToJson" -}}
{{- $config := dict -}}
{{- range $k, $v := . -}}
{{- if kindIs "map" $v -}}
{{- $config = set $config (snakecase $k) (include "yamlToJson" $v | fromYaml ) -}}
{{- else -}}
{{- $config = set $config (snakecase $k) $v -}}
{{- end -}}
{{- end -}}
{{- $config | toYaml -}}
{{- end -}}

{{- define "ra-self-hosted.cert-secret-name" }}
{{- if .Values.tls.useCertManager -}}
{{- printf "%s-%s" (include "ra-self-hosted.fullname" .) "tls" | trunc 63 }}
{{- else -}}
{{- .Values.tls.existingSecret -}}
{{- end -}}
{{- end -}}