{{- /*
Tekmetric Common Chart - Label Helpers
Standard Kubernetes labels following best practices
*/ -}}

{{- /*
Common labels applied to all resources
*/ -}}
{{- define "tekmetric.labels" -}}
helm.sh/chart: {{ include "tekmetric.chart" . }}
{{ include "tekmetric.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- /*
Selector labels for matching pods
*/ -}}
{{- define "tekmetric.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tekmetric.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
