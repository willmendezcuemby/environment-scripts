#!/bin/bash

BASE_DIR="$1"
ENV_CHOICE="$2"
NAMESPACE_MAP="$3"

# Services array
services=("$4") # You can specify the service when running the script

# Check if environment exists
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


# Parse environments
chosen_envs=()

if [[ "$ENV_CHOICE" == "all" ]]; then
    chosen_envs=("dev" "release" "prod")
else
    IFS=',' read -ra chosen_envs <<< "$ENV_CHOICE"
fi

# Parse namespaces
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

# Create directories and generate overlays for specified service
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
