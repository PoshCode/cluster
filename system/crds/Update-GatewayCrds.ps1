param(
    $Version = "v1.2.0"
)
Push-Location $PSScriptRoot

Invoke-RestMethod https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/$Version/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml > gateway-networking-$Version-gatewayclasses.yaml
Invoke-RestMethod https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/$Version/config/crd/experimental/gateway.networking.k8s.io_gateways.yaml > gateway-networking-$Version-gateways.yaml
Invoke-RestMethod https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/$Version/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml > gateway-networking-$Version-httproutes.yaml
Invoke-RestMethod https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/$Version/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml > gateway-networking-$Version-referencegrants.yaml
Invoke-RestMethod https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/$Version/config/crd/experimental/gateway.networking.k8s.io_grpcroutes.yaml > gateway-networking-$Version-grpcroutes.yaml
Invoke-RestMethod https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/$Version/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml > gateway-networking-$Version-tlsroutes.yaml

Pop-Location