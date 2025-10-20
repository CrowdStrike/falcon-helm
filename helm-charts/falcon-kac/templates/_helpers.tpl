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

{{/*
Create Watcher container environment variables
*/}}
{{- define "falcon-kac.generateWatcherEnvVars" -}}
{{- $snapshotsEnabled := true -}}
{{- $snapshotInterval := "22h" -}}
{{- $watcherEnabled := true -}}
{{- $configMapEnabled := true -}}
{{- if .Values.clusterVisibility -}}
{{- if .Values.clusterVisibility.resourceSnapshots -}}
  {{- if ne .Values.clusterVisibility.resourceSnapshots.enabled nil -}}
  {{ $snapshotsEnabled = .Values.clusterVisibility.resourceSnapshots.enabled -}}
  {{- end -}}
  {{- if .Values.clusterVisibility.resourceSnapshots.interval -}}
  {{ $snapshotInterval = .Values.clusterVisibility.resourceSnapshots.interval -}}
  {{- end -}}
{{- end -}}
{{- if .Values.clusterVisibility.resourceWatcher -}}
  {{- if ne .Values.clusterVisibility.resourceWatcher.enabled nil -}}
  {{ $watcherEnabled = .Values.clusterVisibility.resourceWatcher.enabled -}}
  {{- end -}}
{{- end -}}
{{- if .Values.clusterVisibility.resourceConfigMap -}}
  {{- if ne .Values.clusterVisibility.resourceConfigMap.enabled nil -}}
  {{ $configMapEnabled = .Values.clusterVisibility.resourceConfigMap.enabled -}}
  {{- end -}}
{{- end -}}
{{- end -}}
__CS_SNAPSHOTS_ENABLED: {{ $snapshotsEnabled | toString | quote }}
__CS_SNAPSHOT_INTERVAL: {{ $snapshotInterval | toString | quote }}
__CS_WATCH_EVENTS_ENABLED: {{ $watcherEnabled | toString | quote }}
__CS_VISIBILITY_CONFIGMAPS_ENABLED: {{ $configMapEnabled | toString | quote }}
{{- end -}}

{{- define "validateValues" }}
  {{- if and (eq (include "admissionControlEnabled" .) "false") (eq (include "visibilityEnabled" .) "false") }}
    {{- fail "Error: .Values.admissionControl.enabled, .Values.clusterVisibility.resourceSnapshots.enabled, .Values.clusterVisibility.resourceWatcher.enabled cannot all be false." }}
  {{- end }}
{{- end }}

{{- define "visibilityEnabled" -}}
  {{- if or .Values.clusterVisibility.resourceSnapshots.enabled .Values.clusterVisibility.resourceWatcher.enabled -}}
    true
  {{- else -}}
    false
  {{- end -}}
{{- end }}

{{- define "admissionControlEnabled" -}}
  {{- if .Values.admissionControl.enabled -}}
    true
  {{- else -}}
    false
  {{- end -}}
{{- end }}

{{/*
Return namespace based on .Values.namespaceOverride or Release.Namespace
namespaceOverride should only be used when installing falcon-kac as a subchart of falcon-platform
*/}}
{{- define "falcon-kac.namespace" -}}
{{- if .Values.namespaceOverride -}}
{{- .Values.namespaceOverride -}}
{{- else -}}
{{- .Release.Namespace -}}
{{- end -}}
{{- end -}}


{{/* ### GLOBAL HELPERS ### */}}

{{/*
Get Falcon CID from global value if it exists
*/}}
{{- define "falcon-kac.falconCid" -}}
{{- if and .Values.global.falcon.cid (not .Values.falcon.cid) -}}
{{- .Values.global.falcon.cid -}}
{{- else -}}
{{- .Values.falcon.cid | default "" -}}
{{- end -}}
{{- end -}}

{{/*
Check if Falcon secret is enabled from global value if it exists
*/}}
{{- define "falcon-kac.falconSecretEnabled" -}}
{{- or .Values.global.falconSecret.enabled .Values.falconSecret.enabled -}}
{{- end -}}

{{/*
Get Falcon secret name from global value if it exists
*/}}
{{- define "falcon-kac.falconSecretName" -}}
{{- if and .Values.global.falconSecret.secretName (not .Values.falconSecret.secretName) -}}
{{- .Values.global.falconSecret.secretName -}}
{{- else -}}
{{- .Values.falconSecret.secretName | default "" -}}
{{- end -}}
{{- end -}}

{{/*
Validate one of falcon.cid or falconSecret is configured
*/}}
{{- define "falcon-kac.validateOneOfFalconCidOrFalconSecret" -}}
{{- $hasCid := include "falcon-kac.falconCid" . -}}
{{- $secretEnabled := (include "falcon-kac.falconSecretEnabled" . | eq "true") -}}
{{- $hasSecret := include "falcon-kac.falconSecretName" . -}}

{{- if and (not $hasCid) (or (not $secretEnabled) (not $hasSecret)) -}}
{{- fail "Must configure one of falcon.cid or falconSecret with FALCONCTL_OPT_CID data" }}
{{- end -}}

{{- if and ($hasCid) ($secretEnabled) -}}
{{- fail "Cannot use both falcon.cid and falconSecret" }}
{{- end -}}
{{- end -}}

{{/*
Get container registry pull secret from global value if it exists
*/}}
{{- define "falcon-kac.imagePullSecret" -}}
{{- if and .Values.global.containerRegistry.pullSecret (not .Values.image.pullSecrets) -}}
{{- .Values.global.containerRegistry.pullSecret -}}
{{- else -}}
{{- .Values.image.pullSecrets | default "" -}}
{{- end -}}
{{- end -}}

{{/*
Get container registry config json from global value if it exists
*/}}
{{- define "falcon-kac.registryConfigJson" -}}
{{- if and .Values.global.containerRegistry.configJSON (not .Values.image.registryConfigJSON) -}}
{{- .Values.global.containerRegistry.configJSON -}}
{{- else -}}
{{- .Values.image.registryConfigJSON | default "" -}}
{{- end -}}
{{- end -}}
