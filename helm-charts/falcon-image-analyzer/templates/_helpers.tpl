{{/*
Expand the name of the chart.
*/}}
{{- define "falcon-image-analyzer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "falcon-image-analyzer.fullname" -}}
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
{{- define "falcon-image-analyzer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
agentRunmode definition
*/}}
{{- define "falcon-image-analyzer.agentrunmode" -}}
{{- if .Values.daemonset.enabled }}
{{- printf "socket" }}
{{- else if .Values.deployment.enabled }}
{{- printf "watcher" }}
{{- end }}
{{- end }}


{{/*
isKubernetes definition
*/}}
{{- define "falcon-image-analyzer.isKubernetes" -}}
{{- printf "true" }}
{{- end }}


{{/*
iar agent service  definition
*/}}
{{- define "falcon-image-analyzer.iarAgentService" -}}
{{- printf "iar-agent-service" }}
{{- end }}

{{/*
tmp-volume volume size definition
*/}}
{{- define "falcon-image-analyzer.tempvolsize" -}}
{{- range $v := .Values.volumes }}
{{- if eq $v.name "tmp-volume" }}
{{- printf $v.emptyDir.sizeLimit }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "falcon-image-analyzer.labels" -}}
app.kubernetes.io/component: iar
crowdstrike.com/provider: crowdstrike
helm.sh/chart: {{ include "falcon-image-analyzer.chart" . }}
{{ include "falcon-image-analyzer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Labels for test resources — excludes selector labels to prevent adoption by DaemonSet/Deployment.
*/}}
{{- define "falcon-image-analyzer.testLabels" -}}
helm.sh/chart: {{ include "falcon-image-analyzer.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "falcon-image-analyzer.selectorLabels" -}}
app: falcon-image-analyzer
app.kubernetes.io/name: {{ include "falcon-image-analyzer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "falcon-image-analyzer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "falcon-image-analyzer.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "falcon-image-analyzer.securityContext" -}}
{{- if .Values.daemonset.enabled -}}
privileged: {{ .Values.securityContext.privileged | default true }}
allowPrivilegeEscalation: {{ .Values.securityContext.allowPrivilegeEscalation | default true }}
runAsUser: {{ .Values.securityContext.runAsUser | default 0 }}
runAsGroup: {{ .Values.securityContext.runAsGroup | default 0 }}
{{- end }}
{{- end }}

{{- define "falcon-image-analyzer.volumeMounts" -}}
{{- if lt (len .Values.volumeMounts) 2 -}}
{{- .Values.volumeMounts | toYaml }}
{{- if .Values.daemonset.enabled }}
- name: var-run
  mountPath: {{ trimPrefix "unix://" (include "falcon-image-analyzer.agentRuntimeSocket" . ) }}
{{- if eq .Values.crowdstrikeConfig.agentRuntime "crio" }}
- name: storage
  mountPath: /run/containers/storage
- name: containers
  mountPath: /var/lib/containers
- name: fuse-overlay
  mountPath: /usr/bin/fuse-overlayfs
- name: crio-conf
  mountPath: /etc/containers
{{- end }}
{{- end }}
{{- else -}}
{{- .Values.volumeMounts | toYaml }}
{{- end }}
{{- end }}

{{- define "falcon-image-analyzer.volumes" -}}
{{- if lt (len .Values.volumes) 2 -}}
{{- .Values.volumes | toYaml }}
{{- if .Values.daemonset.enabled }}
- name: var-run
  hostPath:
    path: {{ trimPrefix "unix://" (include "falcon-image-analyzer.agentRuntimeSocket" . ) }}
    type: Socket
{{- if eq .Values.crowdstrikeConfig.agentRuntime "crio" }}
- name: storage
  hostPath:
    path: /run/containers/storage
    type: Directory
- name: containers
  hostPath:
    path: /var/lib/containers
    type: Directory
- name: crio-conf
  hostPath:
    path: /etc/containers
    type: Directory
- name: fuse-overlay
  hostPath:
    path: /usr/bin/fuse-overlayfs
    type: File
{{- end }}
{{- end }}
{{- else -}}
{{- .Values.volumes | toYaml }}
{{- end }}
{{- end }}

{{- define "falcon-image-analyzer.agentRuntimeSocket" -}}
{{- if .Values.daemonset.enabled }}
{{- if not .Values.crowdstrikeConfig.agentRuntimeSocket }}
{{- if eq .Values.crowdstrikeConfig.agentRuntime "docker" }}
{{- printf "%s" "unix:///run/docker.sock" }}
{{- else if eq .Values.crowdstrikeConfig.agentRuntime "containerd" -}}
{{- printf "%s" "unix:///run/containerd/containerd.sock" }}
{{- else if eq .Values.crowdstrikeConfig.agentRuntime "crio" -}}
{{- printf "%s" "unix:///run/crio/crio.sock" }}
{{- else if eq .Values.crowdstrikeConfig.agentRuntime "podman" -}}
{{- printf "%s" "unix:///run/podman/podman.sock" }}
{{- end }}
{{- else -}}
{{- .Values.crowdstrikeConfig.agentRuntimeSocket }}
{{- end }}
{{- end }}
{{- end }}

{{- define "falcon-image-analyzer.pullSecretFromAPIToken" }}
{{- with .Values.crowdstrikeConfig }}
{{- if or (eq .agentRegion "us-gov-1") (eq .agentRegion "usgov1") (eq .agentRegion "us-gov1") (eq .agentRegion "gov1") (eq .agentRegion "gov-1") }}
{{- printf "{\"auths\":{\"registry.laggar.gcw.crowdstrike.com\":{\"username\":\"fc-%s\",\"password\":\"%s\",\"email\":\"image-assessment@crowdstrike.com\",\"auth\":\"%s\"}}}" (first (regexSplit "-" (lower .cid) -1)) .dockerAPIToken (printf "fc-%s:%s" (first (regexSplit "-" (lower .cid) -1)) .dockerAPIToken | b64enc) | b64enc }}
{{- else if or (eq .agentRegion "us-gov-2") (eq .agentRegion "usgov2") (eq .agentRegion "us-gov2") (eq .agentRegion "gov2") (eq .agentRegion "gov-2") }}
{{- printf "{\"auths\":{\"registry.us-gov-2.crowdstrike.mil\":{\"username\":\"fc-%s\",\"password\":\"%s\",\"email\":\"image-assessment@crowdstrike.com\",\"auth\":\"%s\"}}}" (first (regexSplit "-" (lower .cid) -1)) .dockerAPIToken (printf "fc-%s:%s" (first (regexSplit "-" (lower .cid) -1)) .dockerAPIToken | b64enc) | b64enc }}
{{- else }}
{{- printf "{\"auths\":{\"registry.crowdstrike.com\":{\"username\":\"fc-%s\",\"password\":\"%s\",\"email\":\"image-assessment@crowdstrike.com\",\"auth\":\"%s\"}}}" (first (regexSplit "-" (lower .cid) -1)) .dockerAPIToken (printf "fc-%s:%s" (first (regexSplit "-" (lower .cid) -1)) .dockerAPIToken | b64enc) | b64enc }}
{{- end }}
{{- end }}
{{- end }}

{{- define "falcon-image-analyzer.image" -}}
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
Return namespace based on .Values.namespaceOverride or Release.Namespace
namespaceOverride should only be used when installing falcon-image-analyzer as a subchart of falcon-platform
*/}}
{{- define "falcon-image-analyzer.namespace" -}}
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
{{- define "falcon-image-analyzer.falconCid" -}}
{{- $globalCid := .Values.global.falcon.cid | default "" | trim -}}
{{- $localCid := .Values.crowdstrikeConfig.cid | default "" | trim -}}
{{- if and $globalCid (not $localCid) -}}
{{- $globalCid -}}
{{- else -}}
{{- $localCid -}}
{{- end -}}
{{- end -}}

{{/*
Check if Falcon secret is enabled from global value if it exists
*/}}
{{- define "falcon-image-analyzer.falconSecretEnabled" -}}
{{- $globalEnabled := .Values.global.falconSecret.enabled | default false -}}
{{- $existingSecret := .Values.crowdstrikeConfig.existingSecret | default "" -}}
{{- or $globalEnabled $existingSecret -}}
{{- end -}}

{{/*
Get Falcon secret name from global value if it exists
*/}}
{{- define "falcon-image-analyzer.falconSecretName" -}}
{{- $globalSecretName := .Values.global.falconSecret.secretName | default "" -}}
{{- $existingSecret := .Values.crowdstrikeConfig.existingSecret | default "" -}}
{{- if and $globalSecretName (not $existingSecret) -}}
{{- $globalSecretName -}}
{{- else -}}
{{- $existingSecret -}}
{{- end -}}
{{- end -}}

{{/*
Check if the chart should create a secret with clientId/clientSecret keys.
Returns "true" if both clientID and clientSecret are provided in crowdstrikeConfig.
When true, the chart creates a managed secret containing AGENT_CLIENT_ID and AGENT_CLIENT_SECRET.
*/}}
{{- define "falcon-image-analyzer.shouldCreateClientCredsInSecret" -}}
{{- $hasClientId := .Values.crowdstrikeConfig.clientID | default "" | trim -}}
{{- $hasClientSecret := .Values.crowdstrikeConfig.clientSecret | default "" | trim -}}
{{- if and $hasClientId $hasClientSecret -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
Get the name of the Kubernetes secret that will be created by the CSI driver.
This is separate from falconSecret.secretName to allow independent configuration.
*/}}
{{- define "falcon-image-analyzer.csiSecretName" -}}
{{- $csiSecretName := .Values.secretsStore.secretName | default .Values.global.secretsStore.secretName -}}
{{- if $csiSecretName -}}
{{- $csiSecretName -}}
{{- else -}}
{{- printf "%s-csi" (include "falcon-image-analyzer.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Returns true when Secrets Store CSI is enabled.
Component-level setting overrides global setting.
*/}}
{{- define "falcon-image-analyzer.csiEnabled" -}}
{{- if eq .Values.secretsStore.enabled false -}}
  {{- /* Explicitly disabled - don't check global */}}
{{- else if or .Values.secretsStore.enabled .Values.global.secretsStore.enabled -}}
true
{{- end -}}
{{- end -}}

{{/*
Returns the effective CSI provider (local overrides global).
*/}}
{{- define "falcon-image-analyzer.csiProvider" -}}
{{- .Values.secretsStore.provider | default .Values.global.secretsStore.provider -}}
{{- end -}}

{{/*
Get container registry pull secret from global value if it exists
*/}}
{{- define "falcon-image-analyzer.imagePullSecret" -}}
{{- if and .Values.global.containerRegistry.pullSecret (not .Values.image.pullSecret) -}}
{{- .Values.global.containerRegistry.pullSecret -}}
{{- else -}}
{{- .Values.image.pullSecret | default "" -}}
{{- end -}}
{{- end -}}

{{/*
Get container registry config json from global value if it exists
*/}}
{{- define "falcon-image-analyzer.registryConfigJson" -}}
{{- if and .Values.global.containerRegistry.configJSON (not .Values.image.registryConfigJSON) -}}
{{- .Values.global.containerRegistry.configJSON -}}
{{- else -}}
{{- .Values.image.registryConfigJSON | default "" -}}
{{- end -}}
{{- end -}}

{{/*
OpenShift SCC name. Uses openshift.sccName if set, otherwise defaults to the fullname.
*/}}
{{- define "falcon-image-analyzer.sccName" -}}
{{- if .Values.openshift.sccName -}}
{{- .Values.openshift.sccName -}}
{{- else -}}
{{- include "falcon-image-analyzer.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
OpenShift mode enabled — true if either chart-level or global is true.
*/}}
{{- define "falcon-image-analyzer.openshiftEnabled" -}}
{{- or .Values.openshift.enabled .Values.global.openshift.enabled -}}
{{- end -}}

{{/*
OpenShift createSCC — false if either chart-level or global disables it.
*/}}
{{- define "falcon-image-analyzer.openshiftCreateSCC" -}}
{{- and .Values.openshift.createSCC .Values.global.openshift.createSCC -}}
{{- end -}}

{{/*
Perform all validations and fail with combined error message if any are invalid.
Call this at the top of your main templates to validate all credential inputs.
*/}}
{{- define "falcon-image-analyzer.validateCredentials" -}}
{{- $errors := list -}}

{{- /* Check if credentials are required (no external/global secret, and no CSI driver) */ -}}
{{- $globalSecretEnabled := .Values.global.falconSecret.enabled | default false -}}
{{- $existingSecret := .Values.crowdstrikeConfig.existingSecret | default "" | trim -}}
{{- $csiEnabled := include "falcon-image-analyzer.csiEnabled" . | eq "true" -}}
{{- $needsCredentials := and (not $globalSecretEnabled) (not $existingSecret) (not $csiEnabled) -}}

{{- /* Validate clientID and clientSecret are provided as a pair */ -}}
{{- $clientId := .Values.crowdstrikeConfig.clientID | default "" | trim -}}
{{- $clientSecret := .Values.crowdstrikeConfig.clientSecret | default "" | trim -}}
{{- $hasClientId := ne $clientId "" -}}
{{- $hasClientSecret := ne $clientSecret "" -}}

{{- if and $hasClientId (not $hasClientSecret) -}}
  {{- $errors = append $errors "clientSecret is required when clientID is provided (must be provided as a pair)" -}}
{{- end -}}
{{- if and $hasClientSecret (not $hasClientId) -}}
  {{- $errors = append $errors "clientID is required when clientSecret is provided (must be provided as a pair)" -}}
{{- end -}}

{{- if $needsCredentials -}}
  {{- /* Validate clientID and clientSecret are provided */ -}}
  {{- if not $hasClientId -}}
    {{- $errors = append $errors "clientID is required when no existingSecret or global.falconSecret is configured" -}}
  {{- end -}}
  {{- if not $hasClientSecret -}}
    {{- $errors = append $errors "clientSecret is required when no existingSecret or global.falconSecret is configured" -}}
  {{- end -}}

  {{- /* Validate CID is provided (either local or global) */ -}}
  {{- $cid := include "falcon-image-analyzer.falconCid" . | trim -}}
  {{- if not $cid -}}
    {{- $errors = append $errors "CID is required (set crowdstrikeConfig.cid or global.falcon.cid) when no existingSecret or global.falconSecret is configured" -}}
  {{- end -}}
{{- end -}}

{{- if $errors -}}
{{- fail (printf "Credential validation failed:\n  - %s" (join "\n  - " $errors)) -}}
{{- end -}}
{{- end -}}
