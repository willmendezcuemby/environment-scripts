#!/bin/bash

delete_environment() {
    local current_dir="$1"
    local env_to_delete="$2"

    for dir in "$current_dir"/*; do
        if [[ -d "$dir" ]]; then
            if [[ $(basename "$dir") == "$env_to_delete" ]]; then
                rm -r "$dir"
                echo "Deleted $dir"
            else
                # Recurse into the directory to check further
                delete_environment "$dir" "$env_to_delete"
            fi
        fi
    done
}

# Directory where all the service directories reside
BASE_DIR="$1"

# Environment you want to delete
ENV_TO_DELETE="$2"

# Ensure both base directory and environment to delete are provided
if [[ -z "$BASE_DIR" || -z "$ENV_TO_DELETE" ]]; then
    echo "Usage: $0 [BASE_DIR] [ENV_TO_DELETE]"
    exit 1
fi

# Check if the base directory exists
if [[ ! -d "$BASE_DIR" ]]; then
    echo "Error: The base directory $BASE_DIR does not exist."
    exit 1
fi

delete_environment "$BASE_DIR" "$ENV_TO_DELETE"

echo "Deletion of environment $ENV_TO_DELETE completed!"
