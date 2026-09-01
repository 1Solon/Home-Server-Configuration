---
apiVersion: v1alpha1
kind: ResolverConfig
nameservers:
  - address: {{ .Data.nameserver }}
searchDomains:
  disableDefault: false
---
apiVersion: v1alpha1
kind: LinkConfig
name: {{ .Node.Data.networkInterface }}
addresses:
  - address: {{ .Node.IP }}/24
routes:
  - gateway: {{ .Data.gateway }}
