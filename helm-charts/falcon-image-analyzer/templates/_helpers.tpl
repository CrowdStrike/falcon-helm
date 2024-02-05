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
Common labels
*/}}
{{- define "falcon-image-analyzer.labels" -}}
helm.sh/chart: {{ include "falcon-image-analyzer.chart" . }}
{{ include "falcon-image-analyzer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "falcon-image-analyzer.selectorLabels" -}}
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

{{- define "falcon-image-analyzer.imagePullSecret" }}
{{- with .Values.crowdstrikeConfig }}
{{- if eq .agentRegion "us-gov-1" }}
{{- printf "{\"auths\":{\"registry.laggar.gcw.crowdstrike.com\":{\"username\":\"fc-%s\",\"password\":\"%s\",\"email\":\"image-assessment@crowdstrike.com\",\"auth\":\"%s\"}}}" (first (regexSplit "-" (lower .cid) -1)) .dockerAPIToken (printf "fc-%s:%s" (first (regexSplit "-" (lower .cid) -1)) .dockerAPIToken | b64enc) | b64enc }}
{{- else if eq .agentRegion "us-gov-2" }}
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
