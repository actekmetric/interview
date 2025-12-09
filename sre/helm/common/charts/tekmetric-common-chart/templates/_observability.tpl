{{- /*
Tekmetric Common Chart - Observability Configuration
OpenTelemetry integration for metrics, traces, and logs
*/ -}}

{{- define "tekmetric.observability.env" -}}
{{- if .Values.observability.otel.enabled }}
- name: OTEL_SERVICE_NAME
  value: {{ include "tekmetric.fullname" . }}
- name: OTEL_RESOURCE_ATTRIBUTES
  value: "service.name={{ include "tekmetric.fullname" . }},service.namespace={{ include "tekmetric.namespace" . }},service.version={{ .Chart.AppVersion }}"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ .Values.observability.otel.endpoint | default "http://otel-collector:4318" | quote }}
{{- if .Values.observability.otel.protocol }}
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: {{ .Values.observability.otel.protocol | quote }}
{{- end }}
{{- if .Values.jvm.enabled }}
- name: JAVA_TOOL_OPTIONS
  value: "-javaagent:/opt/opentelemetry/javaagent.jar {{ .Values.observability.otel.javaOptions | default "" }}"
{{- end }}
{{- with .Values.observability.otel.additionalEnv }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}
