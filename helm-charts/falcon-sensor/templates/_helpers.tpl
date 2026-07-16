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
Labels for test resources — excludes selector labels to prevent adoption by DaemonSet/Deployment.
*/}}
{{- define "falcon-sensor.testLabels" -}}
helm.sh/chart: {{ include "falcon-sensor.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
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


{{/*
Create init script for daemonset
*/}}
{{- define "falcon-sensor.initArgs" -}}
args:
  - '-c'
  - >-
      set -e;
      if [ ! -f /opt/CrowdStrike/falcon-daemonset-init ]; then
      echo "Error: This is not a falcon node sensor(DaemonSet) image";
      exit 1;
      fi;
      echo "Running /opt/CrowdStrike/falcon-daemonset-init -i";
      /opt/CrowdStrike/falcon-daemonset-init -i;
      if [ ! -f /opt/CrowdStrike/configure-cluster-id ]; then
      echo "/opt/CrowdStrike/configure-cluster-id not found. Skipping.";
      else
      echo "Running /opt/CrowdStrike/configure-cluster-id";
      /opt/CrowdStrike/configure-cluster-id;
      fi
{{- end -}}

{{/*
Create the name of the config map if GKE Autopilot is used.
WorkloadAllowlists require an exact match for naming.
*/}}
{{- define "falcon-sensor.configMapName" -}}
{{- if and .Values.node.gke.autopilot -}}
{{- printf "falcon-node-sensor-config" -}}
{{- else -}}
{{- printf "%s-config" (include "falcon-sensor.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Add label for WorkloadAllowlist for the deploy daemonset
*/}}
{{- define "falcon-sensor.workloadDeployAllowlistLabel" -}}
{{- if and .Values.node.gke.autopilot .Values.node.enabled .Values.node.gke.deployAllowListVersion -}}
{{- printf "cloud.google.com/matching-allowlist: \"crowdstrike-falconsensor-deploy-allowlist-%s\"" .Values.node.gke.deployAllowListVersion -}}
{{- end -}}
{{- end -}}

{{/*
Add label for WorkloadAllowlist for the cleanup daemonset
*/}}
{{- define "falcon-sensor.workloadCleanupAllowlistLabel" -}}
{{- if and .Values.node.gke.autopilot .Values.node.enabled .Values.node.gke.cleanupAllowListVersion -}}
{{- printf "cloud.google.com/matching-allowlist: \"crowdstrike-falconsensor-cleanup-allowlist-%s\"" .Values.node.gke.cleanupAllowListVersion -}}
{{- end -}}
{{- end -}}

{{/*
Create service account name for the cleanup daemonset
*/}}
{{- define "falcon-sensor.cleanupServiceAccountName" -}}
{{- if not .Values.node.cleanupOnly -}}
{{- printf "%s-node-cleanup" .Values.serviceAccount.name -}}
{{- else -}}
{{- printf "%s-node-cleanup-standalone" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}


{{/*
Return namespace based on .Values.namespaceOverride or Release.Namespace
*/}}
{{- define "falcon-sensor.namespace" -}}
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
{{- define "falcon-sensor.falconCid" -}}
{{- if and .Values.global.falcon.cid (not .Values.falcon.cid) -}}
{{- .Values.global.falcon.cid -}}
{{- else -}}
{{- .Values.falcon.cid | default "" -}}
{{- end -}}
{{- end -}}

{{/*
Check if Falcon secret is enabled from global value if it exists.
*/}}
{{- define "falcon-sensor.falconSecretEnabled" -}}
{{- or .Values.global.falconSecret.enabled .Values.falconSecret.enabled -}}
{{- end -}}

{{/*
Get Falcon secret name from global value if it exists.
When Secrets Store CSI is enabled, returns the name of the secret that
SecretProviderClass.secretObjects will sync from the secrets store, so that the
existing envFrom/secretRef wiring picks it up unchanged.
*/}}
{{- define "falcon-sensor.falconSecretName" -}}
{{- if and .Values.global.falconSecret.secretName (not .Values.falconSecret.secretName) -}}
{{- .Values.global.falconSecret.secretName -}}
{{- else -}}
{{- .Values.falconSecret.secretName | default "" -}}
{{- end -}}
{{- end -}}

{{/*
Get the name of the Kubernetes secret that will be created by the CSI driver.
This is separate from falconSecret.secretName to allow independent configuration.
*/}}
{{- define "falcon-sensor.csiSecretName" -}}
{{- $csiSecretName := .Values.secretsStore.secretName | default .Values.global.secretsStore.secretName -}}
{{- if $csiSecretName -}}
{{- $csiSecretName -}}
{{- else -}}
{{- printf "%s-csi" (include "falcon-sensor.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Returns true when Secrets Store CSI is enabled.
Component-level setting overrides global setting.
*/}}
{{- define "falcon-sensor.csiEnabled" -}}
{{- if eq .Values.secretsStore.enabled false -}}
  {{- /* Explicitly disabled - don't check global */}}
{{- else if or .Values.secretsStore.enabled .Values.global.secretsStore.enabled -}}
true
{{- end -}}
{{- end -}}

{{/*
Returns the effective CSI provider (local overrides global).
*/}}
{{- define "falcon-sensor.csiProvider" -}}
{{- .Values.secretsStore.provider | default .Values.global.secretsStore.provider -}}
{{- end -}}

{{/*
Validate one of falcon.cid, falconSecret, or secretsStore is configured
*/}}
{{- define "falcon-sensor.validateOneOfFalconCidOrFalconSecret" -}}
{{- $hasCid := include "falcon-sensor.falconCid" . -}}
{{- $secretEnabled := (include "falcon-sensor.falconSecretEnabled" . | eq "true") -}}
{{- $hasSecret := include "falcon-sensor.falconSecretName" . -}}
{{- $csiEnabled := (include "falcon-sensor.csiEnabled" . | eq "true") -}}

{{- if and (not $hasCid) (or (not $secretEnabled) (not $hasSecret)) (not $csiEnabled) -}}
{{- fail "Must configure one of falcon.cid, falconSecret with FALCONCTL_OPT_CID data, or secretsStore" }}
{{- end -}}

{{- if and ($hasCid) ($secretEnabled) -}}
{{- fail "Cannot use both falcon.cid and falconSecret" }}
{{- end -}}
{{- end -}}

{{/*
Validate falconSecret.secretName
*/}}
{{- define "falcon-sensor.validateFalconSecretName" -}}
{{- $falconSecretName := include "falcon-sensor.falconSecretName" . }}
{{- $gkeAutopilotEnabled := (dig "node" "gke" "autopilot" false .Values.AsMap | eq true) -}}
{{- $falconSecretNameIsAllowed := $falconSecretName | eq "falcon-node-sensor-secret" -}}

{{- if and $falconSecretName $gkeAutopilotEnabled (not $falconSecretNameIsAllowed) -}}
{{- fail "falconSecret.secretName must be \"falcon-node-sensor-secret\" when GKE Autopilot is enabled" }}
{{- end -}}
{{- end -}}

{{/*
Get node container registry pull secret from global value if it exists
*/}}
{{- define "falcon-sensor.node.imagePullSecretName" -}}
{{- if and .Values.global.containerRegistry.pullSecret (not .Values.node.image.pullSecrets) -}}
{{- .Values.global.containerRegistry.pullSecret -}}
{{- else -}}
{{- .Values.node.image.pullSecrets | default "" -}}
{{- end -}}
{{- end -}}

{{/*
Get sidecar container registry pull secret from global value if it exists
*/}}
{{- define "falcon-sensor.container.imagePullSecretName" -}}
{{- if and .Values.global.containerRegistry.pullSecret (not .Values.container.image.pullSecrets.name) -}}
{{- .Values.global.containerRegistry.pullSecret -}}
{{- else -}}
{{- .Values.container.image.pullSecrets.name | default "" -}}
{{- end -}}
{{- end -}}

{{/*
Get node container registry config json from global value if it exists
*/}}
{{- define "falcon-sensor.node.registryConfigJson" -}}
{{- if and .Values.global.containerRegistry.configJSON (not .Values.node.image.registryConfigJSON) -}}
{{- .Values.global.containerRegistry.configJSON -}}
{{- else -}}
{{- .Values.node.image.registryConfigJSON | default "" -}}
{{- end -}}
{{- end -}}

{{/*
Get sidecar container registry config json from global value if it exists
*/}}
{{- define "falcon-sensor.container.registryConfigJson" -}}
{{- if and .Values.global.containerRegistry.configJSON (not .Values.container.image.pullSecrets.registryConfigJSON) -}}
{{- .Values.global.containerRegistry.configJSON -}}
{{- else -}}
{{- .Values.container.image.pullSecrets.registryConfigJSON | default "" -}}
{{- end -}}
{{- end -}}

{{/*
Get the name of the AITap AI-DR secret.
*/}}
{{- define "falcon-sensor.container.aitapAidrSecretName" -}}
{{- if .Values.container.aitap.aidrSecretName -}}
{{- .Values.container.aitap.aidrSecretName -}}
{{- else -}}
{{- printf "%s-aitap-aidr-secret" (include "falcon-sensor.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Validate AITap configuration.
*/}}
{{- define "falcon-sensor.validateAitapConfig" -}}
{{- if and .Values.container.aitap.namespaces .Values.container.aitap.allNamespaces -}}
{{- fail "AITap: 'container.aitap.namespaces' and 'container.aitap.allNamespaces' cannot both be set. Use 'allNamespaces: true' to enable AITap in all namespaces, or list specific namespaces with 'namespaces'." -}}
{{- end -}}
{{- if or .Values.container.aitap.namespaces .Values.container.aitap.allNamespaces -}}
{{- if not .Values.container.aitap.aidrCollectorBaseApiUrl -}}
{{- fail "AITap: 'container.aitap.aidrCollectorBaseApiUrl' is required. Provide the base URL for the AI-DR collector API (e.g. https://your-collector-host)." -}}
{{- end -}}
{{- if not (or .Values.container.aitap.useExistingSecret .Values.container.aitap.aidrCollectorApiToken) -}}
{{- fail "AITap: 'container.aitap.aidrCollectorApiToken' is required." -}}
{{- end -}}
{{- end -}}
{{- if and .Values.container.aitap.useExistingSecret (not .Values.container.aitap.aidrSecretName) -}}
{{- fail "AITap: 'container.aitap.aidrSecretName' is required when 'container.aitap.useExistingSecret' is true. Set this to the name of the existing secret that contains the AI-DR collector token." -}}
{{- end -}}
{{- end -}}

{{/*
OpenShift SCC name for the node DaemonSet.
*/}}
{{- define "falcon-sensor.sccName" -}}
{{- if .Values.node.openshift.sccName -}}
{{- .Values.node.openshift.sccName -}}
{{- else -}}
{{- printf "%s-node-sensor" (include "falcon-sensor.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
OpenShift mode enabled — true if either chart-level or global is true.
*/}}
{{- define "falcon-sensor.openshiftEnabled" -}}
{{- if or .Values.node.openshift.enabled (default false .Values.global.openshift.enabled) -}}
{{- "true" -}}
{{- end -}}
{{- end -}}

{{/*
OpenShift createSCC — false if either chart-level or global disables it.
*/}}
{{- define "falcon-sensor.openshiftCreateSCC" -}}
{{- and .Values.node.openshift.createSCC .Values.global.openshift.createSCC -}}
{{- end -}}

{{/*
Validate OpenShift configuration: container sensor is not supported in OpenShift mode.
*/}}
{{- define "falcon-sensor.validateOpenshiftConfig" -}}
{{- if and (include "falcon-sensor.openshiftEnabled" .) .Values.container.enabled -}}
{{- fail "OpenShift mode (node.openshift.enabled) is only supported with the node DaemonSet. The container sensor (container.enabled) is not fully supported on OpenShift." -}}
{{- end -}}
{{- end -}}
