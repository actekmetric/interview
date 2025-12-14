{{- /*
Tekmetric Common Chart - Environment Variable Helpers
Manages application environment configuration
*/ -}}

{{- define "tekmetric.environment" -}}
{{- if .Values.observability.enabled }}
{{- include "tekmetric.observability.env" . }}
{{- end }}
{{- if .Values.config.configService.enabled }}
- name: CONFIG_SERVICE_URL
  value: {{ .Values.config.configService.url | quote }}
{{- if .Values.config.configService.label }}
- name: CONFIG_LABEL
  value: {{ .Values.config.configService.label | quote }}
{{- end }}
{{- end }}
- name: SERVICE_NAME
  value: {{ include "tekmetric.fullname" . }}
- name: NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: POD_IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
{{- if .Values.jvm.enabled }}
- name: JAVA_OPTS
  value: {{ .Values.jvm.options | default "-Xms512m -Xmx1024m" | quote }}
{{- end }}
{{- end }}
