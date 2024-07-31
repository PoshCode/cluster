# [Loki Helm Chart](https://github.com/grafana/loki/tree/main/production/helm/loki)

DATE: 2024-07-31
CHART VERSION: 6.7.3

TO UPGRADE CHECK: [the upgrade docs](https://grafana.com/docs/loki/next/setup/upgrade/) first.

This chart deploys Loki, but I'm still running it in local single-binary mode, with no persistent (blob) storage.

The current version 6.7.3 deploys Loki 3.0 (with OTLP support, but I'm not using that).