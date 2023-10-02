This cert-manager deployment is a mess. You have to do three steps in order, BEFORE you install anything that needs certs?

1. Run the CRDS separately (because HELM doesn't support CRD upgrades))
2. Run the HELM chart
3. Install these ClusterIssuers (which depend on the webdeploy-hook in the chart)