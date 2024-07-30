param(
    $Version = "0.75.0"
)
Push-Location $PSScriptRoot

Invoke-RestMethod https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v$Version/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml > monitoring.coreos.com_${Version}_alertmanagerconfigs.yaml
Invoke-RestMethod https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v$Version/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml > monitoring.coreos.com_${Version}_alertmanagers.yaml
Invoke-RestMethod https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v$Version/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml > monitoring.coreos.com_${Version}_podmonitors.yaml
Invoke-RestMethod https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v$Version/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml > monitoring.coreos.com_${Version}_probes.yaml
Invoke-RestMethod https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v$Version/example/prometheus-operator-crd/monitoring.coreos.com_prometheusagents.yaml > monitoring.coreos.com_${Version}_prometheusagents.yaml
Invoke-RestMethod https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v$Version/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml > monitoring.coreos.com_${Version}_prometheuses.yaml
Invoke-RestMethod https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v$Version/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml > monitoring.coreos.com_${Version}_prometheusrules.yaml
Invoke-RestMethod https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v$Version/example/prometheus-operator-crd/monitoring.coreos.com_scrapeconfigs.yaml > monitoring.coreos.com_${Version}_scrapeconfigs.yaml
Invoke-RestMethod https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v$Version/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml > monitoring.coreos.com_${Version}_servicemonitors.yaml
Invoke-RestMethod https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v$Version/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml > monitoring.coreos.com_${Version}_thanosrulers.yaml

Pop-Location