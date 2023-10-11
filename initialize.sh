#!/bin/bash

BASE_DIR="$1"
ENV_CHOICE="$2"
NAMESPACE_MAP="$3"


 services=(
   cap-cloud-providers-service
   cap-payments-service
   cap-policy-service
   ccp-account-service
   ccp-application-service
   ccp-autoscaling-service
   ccp-billing-cronjob-oops
   ccp-blockchain-management-service
   ccp-by-email-notification
   ccp-by-uploader
   ccp-byreports-service
   ccp-controlplane-service
   ccp-dashboard-vue
   ccp-events-service
   ccp-eventspods-service
   ccp-infrastructure-operator
   ccp-notification-service
   ccp-payment-service
   ccp-performance-metrics-agent
   ccp-performance-metrics-service
   ccp-performancelogs-agent
   ccp-performancelogs-service
   ccp-pipelines-service
   ccp-registrymanagment-service
   ccp-runtime-service
   ccp-sourceproviders-service
   ccp-tekton-cleanup-cronjob
   ccp-vault-service
   cep-account-service
   cep-pdf-service
   cep-shared-service
   iep-flood-service
   iep-pets-service
   )

environment_exists() {
    local service_name="$1"
    local env="$2"
    local path="$3"

    if [[ -d "$path/$service_name/$env" ]]; then
        return 0
    else
        return 1
    fi
}


generate_overlays() {
    local service_name="$1"
    local env="$2"
    local namespace="$3"
    local path="$4"

    cat > "$path/$service_name-app.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $service_name-$env
  namespace: argocd
spec:
  project: $env
  source:
    repoURL: https://github.com/willmendezcuemby/gitops-ccp
    targetRevision: HEAD
    path: $BASE_DIR/overlays/$service_name/$env
  destination:
    server: https://kubernetes.default.svc
    namespace: $namespace
  syncPolicy:
    automated: {}
EOF

    cat > "$path/deployment-patch.json" <<EOF
[
    {
        "op": "replace",
        "path": "/metadata/name",
        "value": "$service_name-deployment-$env"
    },
    {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/image",
        "value": "image-placeholder-for-$service_name-$env"
    },
    {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/name",
        "value": "$service_name-container"
    },
    {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/envFrom/0/secretRef/name",
        "value": "$service_name-secrets-$env"
    },
    {
        "op": "replace",
        "path": "/spec/selector/matchLabels/app",
        "value": "$service_name-$env"
    },
    {
        "op": "add",
        "path": "/metadata/namespace",
        "value": "$namespace"
    }
]
EOF

cat > "$path/secret-patch.json" <<EOF
[
    {
        "op": "replace",
        "path": "/metadata/name",
        "value": "$service_name-secrets-$env"
    },
    {
        "op": "add",
        "path": "/metadata/namespace",
        "value": "$namespace"
    }
]
EOF

cat > "$path/service-patch.json" <<EOF
[
    {
        "op": "replace",
        "path": "/metadata/name",
        "value": "$service_name-$env"
    },
    {
        "op": "replace",
        "path": "/spec/selector/app",
        "value": "$service_name-$env"
    },
    {
        "op": "add",
        "path": "/metadata/namespace",
        "value": "$namespace"
    }
]
EOF

    # Generate kustomization.yaml
    cat > "$path/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../base

patchesJson6902:
  - target:
      group: apps
      version: v1
      kind: Deployment
      name: service-name
    path: deployment-patch.json
  - target:
      version: v1
      kind: Secret
      name: service-secrets
    path: secret-patch.json
  - target:
      version: v1
      kind: Service
      name: service
    path: service-patch.json
EOF
}

chosen_envs=()

if [[ "$ENV_CHOICE" == "all" ]]; then
    # Define what 'all' entails in your context
    chosen_envs=("dev" "release" "prod")
else
    IFS=',' read -ra chosen_envs <<< "$ENV_CHOICE"
fi

declare -A namespaces
IFS=',' read -ra pairs <<< "$NAMESPACE_MAP"
for pair in "${pairs[@]}"; do
    IFS='=' read -r key val <<< "$pair"
    namespaces["$key"]="$val"
done

# Check and create service directories
for service in "${services[@]}"; do
    if [[ ! -d "$BASE_DIR/overlays/$service" ]]; then
        mkdir -p "$BASE_DIR/overlays/$service"
    fi
done

# Create directories and generate overlays
for service in "${services[@]}"; do
    for env in "${chosen_envs[@]}"; do
        if ! environment_exists "$service" "$env" "$BASE_DIR/overlays"; then
            mkdir -p "$BASE_DIR/overlays/$service/$env" || { echo "Failed to create directory $BASE_DIR/overlays/$service/$env"; exit 1; }
            generate_overlays "$service" "$env" "${namespaces[$env]}" "$BASE_DIR/overlays/$service/$env"
        else
            echo "Environment $env for $service already exists."
        fi
    done
done