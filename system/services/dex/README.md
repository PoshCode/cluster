[Dex](https://dexidp.io/)

DATE: 2023-12-13
CHART VERSION: 1.13.1

This one is a little complicated. In order to get Dex to work right, while still protecting the secrets in the git repo, I ended up deciding to just use the `config.name` setting in the helm chart to specify a secret that has a `config.yaml` file in it.

Obviously, you can't read this one to copy from, so here is an example. You need to replace every `${placeholder value}` in order for it to work, and the staticClient IDs you must synchronize their secrets to the corresponding secret in the client.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: dex-config
  namespace: dex
type: Opaque
stringData:
  config.yaml: | # yaml
    issuer: https://dex.poshcode.com
    connectors:
    - id: github
      name: GitHub
      type: github
      config:
        clientID: ${a github client id}
        clientSecret: ${a github client secret}
        orgs:
        - name: ${a github org}
      redirectURI: https://dex.poshcode.com/callback
    staticClients:
    - id: oauth2-proxy-kube-prometheus-stack
      name: OAuth2 Proxy For Prometheus
      secret: ${a secret which must match the secret in the monitoring namespace}
      redirectURIs:
      - https://prometheus.poshcode.com/oauth2/callback
      - https://alerts.poshcode.com/oauth2/callback
    - id: grafana
      name: Grafana
      secret: ${a secret which must match the secret in the monitoring namespace}
      redirectURIs:
      - https://grafana.poshcode.com/login/generic_oauth
    storage:
      type: kubernetes
      config:
      inCluster: true
```

To generate new client secrets in PowerShell, something like this will work

```powershell
$ValidChars = @('a'..'z') + @('A'..'Z') + @(0..9) + @('-','_',',',':','!','@','#','%','^','*','(',')')
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([char[]]$ValidChars[(Get-Random -Max ($ValidChars.Count - 1) -Count 32)]))
```
