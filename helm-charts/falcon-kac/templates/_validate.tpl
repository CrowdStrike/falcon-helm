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
