# [Kube Prometheus Stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

DATE: 2023-10-01
CHART VERSION: 51.2.0

TO UPGRADE CHECK: [upgrading chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#upgrading-chart) first, because helm still doesn't handle CRD upgrades.

Deploys [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus/blob/main/README.md) which includes ...
- [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics) a service from Kubernetes to generate metrics about the actual objects in kubernetes (deployments, nodes, pods, etc).
- The [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator) for managing Prometheus and Alertmanager
- Parts of [Thanos](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/thanos.md) for storage of data and long term metrics
- A [Node exporter](https://github.com/prometheus/node_exporter/blob/master/README.md) for metrics from the nodes themselves
- [Grafana](https://github.com/grafana/helm-charts/tree/main/charts/grafana)
- And a bunch of pre-configured dashboards and alerts

If we're going to use this we need to follow their docs, and learn [jsonnet](https://jsonnet.org/)...

Particularly for [extending the rules and dashboards](https://github.com/prometheus-operator/kube-prometheus/blob/main/docs/customizations/developing-prometheus-rules-and-grafana-dashboards.md).

## The Big Catch

The prometheus operator does not support annotation-based discovery of services. To scrape [exporters](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/user-guides/running-exporters.md), we must configure [PodMonitor](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/user-guides/getting-started.md#include-podmonitors) or [ServiceMonitor](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/user-guides/getting-started.md#include-servicemonitors) CRDs instead, which provide more configuration options.
