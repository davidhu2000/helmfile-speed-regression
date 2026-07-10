{{- define "slowpoke.fullname" -}}
{{- printf "%s-slowpoke" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "slowpoke.labels" -}}
app.kubernetes.io/name: slowpoke
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "slowpoke.selectorLabels" -}}
app.kubernetes.io/name: slowpoke
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
