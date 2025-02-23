#!/bin/bash

# Generate root CA
openssl genrsa -out ca.key 4096
openssl req -new -x509 -key ca.key -out ca.crt -days 365 -subj "/CN=Local CA"

# Generate server key and CSR
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -subj "/CN=geth-rpc.local"

# Sign the server certificate
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 365 -extensions v3_req \
  -extfile <(echo "[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = geth-rpc.local
DNS.2 = argocd.local
DNS.3 = grafana.local")

# Create Kubernetes TLS secret
kubectl create secret tls geth-tls \
  --cert=server.crt \
  --key=server.key \
  --namespace=ethereum
