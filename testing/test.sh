# /bin/bash
kind --version
# kind version 0.19.0

kind create cluster --name testing --image kindest/node:v1.27.2

#docker pull ghcr.io/fluxcd/helm-controller:v0.32.1 && kind load docker-image --name testing ghcr.io/fluxcd/helm-controller:v0.32.1
#docker pull ghcr.io/fluxcd/image-automation-controller:v0.32.0 && kind load docker-image --name testing ghcr.io/fluxcd/image-automation-controller:v0.32.0
#docker pull ghcr.io/fluxcd/image-reflector-controller:v0.27.0 && kind load docker-image --name testing ghcr.io/fluxcd/image-reflector-controller:v0.27.0
#docker pull ghcr.io/fluxcd/kustomize-controller:v0.25.10 && kind load docker-image --name testing ghcr.io/fluxcd/kustomize-controller:v0.25.10
#docker pull ghcr.io/fluxcd/notification-controller:v0.25.10 && kind load docker-image --name testing ghcr.io/fluxcd/notification-controller:v0.25.10
#docker pull ghcr.io/fluxcd/source-controller:v0.25.10 && kind load docker-image --name testing ghcr.io/fluxcd/source-controller:v0.25.10

kubectl apply -f "v0.37.0.yaml"

kubectl apply -f gotk-sync.yaml

kubectl get ns test -o yaml | grep goldilocks.fairwinds.com/enabled
