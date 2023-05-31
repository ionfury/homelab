# /bin/bash
kind --version
# kind version 0.19.0

kind create cluster --name testing --image kindest/node:v1.24.3

docker pull ghcr.io/fluxcd/helm-controller:v0.32.1 && kind load docker-image --name testing ghcr.io/fluxcd/helm-controller:v0.32.1
docker pull ghcr.io/fluxcd/image-automation-controller:v0.32.0 && kind load docker-image --name testing ghcr.io/fluxcd/image-automation-controller:v0.32.0
docker pull ghcr.io/fluxcd/image-reflector-controller:v0.27.0 && kind load docker-image --name testing ghcr.io/fluxcd/image-reflector-controller:v0.27.0
docker pull ghcr.io/fluxcd/kustomize-controller:v1.0.0-rc.1 && kind load docker-image --name testing ghcr.io/fluxcd/kustomize-controller:v1.0.0-rc.1
docker pull ghcr.io/fluxcd/notification-controller:v1.0.0-rc.1 && kind load docker-image --name testing ghcr.io/fluxcd/notification-controller:v1.0.0-rc.1
docker pull ghcr.io/fluxcd/source-controller:v1.0.0-rc.1 && kind load docker-image --name testing ghcr.io/fluxcd/source-controller:v1.0.0-rc.1

kubectl apply -f testing/gotk-components.yaml

kubectl apply -f testing/gotk-sync.yaml

kubectl get ns test -o yaml
