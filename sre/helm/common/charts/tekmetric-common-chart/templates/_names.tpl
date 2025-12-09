{{- /*
Tekmetric Common Chart - Naming Helpers
Standardized naming functions for Kubernetes resources
*/ -}}

{{- /*
Create chart name
*/ -}}
{{- define "tekmetric.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- /*
Create fully qualified app name
*/ -}}
{{- define "tekmetric.fullname" -}}
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

{{- /*
Create chart name and version for chart label
*/ -}}
{{- define "tekmetric.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- /*
Namespace helper
*/ -}}
{{- define "tekmetric.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride }}
{{- end }}
