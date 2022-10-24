{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "app.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- if eq $name .Chart.Name -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{- define "app.runtime" -}}
{{- default "java" .Values.app.runtime | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "app.labels" -}}
helm.sh/chart: {{ include "app.chart" . }}
{{ include "app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.app }}
app.openshift.io/runtime: {{ .Values.app.runtime }}
{{- end -}}
{{- end -}}


{{/*
Selector labels
*/}}
{{- define "app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "app.name" . }}
app.kubernetes.io/component: {{ include "app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
deploymentconfig: {{ include "app.fullname" . }}
app: {{ include "app.fullname" . }}
version: {{ .Values.image.tag }}
{{- end -}}


{{/*
Resources 
*/}}
{{- define "app.resources" -}}
{{- if .Values.resources }}
resources:
  limits:
    cpu: {{ .Values.resources.limits.cpu }}
    memory: {{ .Values.resources.limits.memory }}
  requests:
    cpu: {{ .Values.resources.requests.cpu }}
    memory: {{ .Values.resources.requests.memory }}
{{ else  }}
resources:
  limits:
    cpu: '1.5'
    memory: 1024Mi
  requests:
    cpu: '500m'
    memory: 512Mi
{{- end -}}
{{- end -}}

{{/*
Prometheus Metrics
*/}}
{{- define "metrics.prometheus" -}}
{{- if .Values.prometheus -}}
prometheus.io/scrape: '{{ .Values.prometheus.scrape }}'
prometheus.io/path: '{{ .Values.prometheus.path }}'
prometheus.io/port: '{{ .Values.prometheus.port }}' 
{{- end -}}
{{- end -}}

{{/*
Liveness Probe
*/}}
{{- define "probes.liveness" -}}
{{- if (.Values.probes).liveness -}}
livenessProbe:
  httpGet:
    path: {{ .Values.probes.liveness.path }}
    port: {{ .Values.probes.liveness.port }}
    scheme: {{ .Values.probes.liveness.scheme | upper }}
  timeoutSeconds: {{ .Values.probes.liveness.timeoutSeconds }}
  periodSeconds: {{ .Values.probes.liveness.periodSeconds }}
  successThreshold: {{ .Values.probes.liveness.successThreshold }}
  failureThreshold: {{ .Values.probes.liveness.failureThreshold }}
{{- end -}}
{{- end -}}

{{/*
Readiness Probs
*/}}
{{- define "probes.readiness" -}}
{{- if (.Values.probes).readiness -}}
readinessProbe:
  httpGet:
    path: {{ .Values.probes.readiness.path }}
    port: {{ .Values.probes.readiness.port }}
    scheme: {{ .Values.probes.readiness.scheme | upper }}
  timeoutSeconds: {{ .Values.probes.readiness.timeoutSeconds }}
  periodSeconds: {{ .Values.probes.readiness.periodSeconds }}
  successThreshold: {{ .Values.probes.readiness.successThreshold }}
  failureThreshold: {{ .Values.probes.readiness.failureThreshold }}
{{- end -}}
{{- end -}}

{{/*
Base Deployment
*/}}

{{- define "base.networkSpec"}}
  {{- if and (ne .Values.controller.type "job") (ne .Values.controller.type "cronjob") }}
  {{- include "common.service" . | nindent 0 }}
  {{- end }}

  {{- if not (hasKey .Values "route") }}
    {{ include "common.route" . | nindent 0 }}
  {{- else if (.Values.route).enabled }}
    {{ include "common.route" . | nindent 0 }}
  {{- end }}
{{- end -}}

{{- define "app.envFromConfigMapRef" -}}
 {{- range $configmap := .Values.services.configmaps }}
- configMapRef:
    name: {{ $configmap }}
  {{- end }}
{{- end -}}

{{- define "app.envFromSecretRef" -}}
 {{- range $secret := .Values.services.secrets }}
- secretRef:
    name: {{ $secret }}
  {{- end }}
{{- end -}}

{{- define "app.envFrom" -}}
{{- if or  ((.Values.services).configmaps)  ((.Values.services).secrets) }}
envFrom:
  {{- include "app.envFromConfigMapRef" . }}
  {{- include "app.envFromSecretRef" . }}
{{- end }}
{{- end -}}

{{- define "app.servicePorts" -}}
{{- if (.Values.service).ports }}
ports:
  {{- range .Values.service.ports }}
  - containerPort: {{.}}
    protocol: TCP
  {{- end}}   
{{- else }}
ports:
 - containerPort: 8080
   protocol: TCP
{{- end}} 
{{- end -}}

{{- define "base.spec" -}}      
      serviceAccountName: {{ include "app.fullname" . }}
      containers:
        - name: {{ include "app.fullname" . }}
          {{- if .Values.image.namespace }}
          image: "{{ .Values.image.repository}}/{{ .Values.image.namespace }}/{{ .Values.image.name }}:{{ .Values.image.tag }}"
          {{- else }}
          image: "{{ .Values.image.repository}}/{{ .Values.image.name }}:{{ .Values.image.tag }}"
          {{- end }}
          imagePullPolicy: Always
          {{ toYaml .Values.env | indent 8 -}}
          {{- include "app.envFrom" . | indent 10 -}}
          {{- include "probes.liveness" . | indent 10 -}}
          {{- include "app.servicePorts"  . | indent 10 -}}
          {{- include "probes.readiness" . | indent 10 -}}
          {{- include "app.resources" . | indent 10 -}}
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
{{- end -}}