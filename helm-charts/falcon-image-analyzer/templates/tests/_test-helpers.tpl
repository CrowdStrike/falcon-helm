{{/*
Test-specific helper functions for Helm chart tests.
These helpers are only used by test manifests and are not part of the production deployment.
*/}}

{{/*
Returns a map of which keys are in the existing secret (true) vs chart-created secret (false).

Usage: {{- $locations := include "falcon-image-analyzer.secretKeyLocations" . | fromYaml -}}
*/}}
{{- define "falcon-image-analyzer.secretKeyLocations" -}}
{{- $existingSecret := include "falcon-image-analyzer.falconSecretName" . | trim -}}
{{- if not $existingSecret -}}
{{- /* No existing secret, so all keys will be in chart-created secret */ -}}
AGENT_CID: false
AGENT_CLIENT_ID: false
AGENT_CLIENT_SECRET: false
{{- else -}}
{{- /* Existing secret configured - check which values are provided directly */ -}}
AGENT_CID: {{ not (include "falcon-image-analyzer.falconCid" . | trim) }}
AGENT_CLIENT_ID: {{ not (.Values.crowdstrikeConfig.clientID | default "" | trim) }}
AGENT_CLIENT_SECRET: {{ not (.Values.crowdstrikeConfig.clientSecret | default "" | trim) }}
{{- end -}}
{{- end -}}
