# GitOps Ethereum Node Deployment

GitOps setup for deploying an Ethereum node (Geth) on Kubernetes with monitoring, logging

## Prerequisites

Required tools and versions:
- Minikube v1.32.0+
- kubectl v1.28.0+
- Helm v3.12.0+
- OpenSSL for certificate generation
- Git

Minimum hardware requirements:
- CPU: 8 cores
- RAM: 14GB
- Storage: 300GB


## Quick Start

```bash
# Clone repository
git clone https://github.com/ayushvgcsns/Gitops-ETH.git
cd Gitops-ETH

# Start Minikube
minikube start --cpus 8 --memory 7168 --disk-size 300g --nodes 2
minikube addons enable ingress

# Install core components
kubectl create namespace ethereum
kubectl create namespace monitoring
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f argocd/application.yaml

# Install Prometheus & Grafana & Loki
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set prometheus.enabled=false \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi

kubectl create secret generic additional-scrape-configs \
  --from-file=prometheus-additional.yaml=<(kubectl get configmap additional-scrape-configs -n monitoring -o jsonpath='{.data.prometheus-additional\.yaml}') \
  --namespace monitoring \
  --dry-run=client -o yaml | kubectl apply -f -

# Update Prometheus with the new configuration
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.additionalScrapeConfigsSecret.enabled=true \
  --set prometheus.prometheusSpec.additionalScrapeConfigsSecret.name=additional-scrape-configs \
  --set prometheus.prometheusSpec.additionalScrapeConfigsSecret.key=prometheus-additional.yaml

kubectl apply -f loki-datasource.yaml
GRAFANA_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath="{.items[0].metadata.name}")
kubectl delete pod $GRAFANA_POD -n monitoring

# Generate certificates
cd manifests/certificates
./generate-certs.sh
cd ../..

## Accessing Services
## Add the following entries to your `/etc/hosts` file:
<minikube-ip> geth-rpc.local geth-ws.local

Geth RPC: https://geth-rpc.local

```



## Cleanup

Remove all resources:

```bash
# Delete ArgoCD applications
kubectl delete -f manifests/argocd/application.yaml

# Uninstall Helm releases
helm uninstall -n ethereum geth
helm uninstall -n monitoring monitoring
helm uninstall -n ingress-nginx ingress-nginx

# Delete namespaces
kubectl delete namespace ethereum monitoring ingress-nginx argocd

# Stop and delete Minikube cluster
minikube stop
minikube delete
```
