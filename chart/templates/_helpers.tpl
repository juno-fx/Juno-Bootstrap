{{- define "omitNulls" }}
{{- $out := dict }}
{{- range $k, $v := . }}
  {{- if kindIs "map" $v }}
    {{- $nested := include "omitNulls" $v | fromYaml }}
    {{- if $nested }}
      {{- $_ := set $out $k $nested }}
    {{- end }}
  {{- else if kindIs "slice" $v }}
    {{- if $v }}
      {{- $_ := set $out $k $v }}
    {{- end }}
  {{- else if ne $v nil }}
    {{- $_ := set $out $k $v }}
  {{- end }}
{{- end }}
{{- toYaml $out }}
{{- end }}
