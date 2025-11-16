#!/bin/bash

# Common functions for encrypt/decrypt scripts
# Source this file: source "$(dirname "$0")/env-crypto.sh"

# Get the project root directory
get_project_root() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    echo "$(cd "$script_dir/.." && pwd)"
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get password from environment or prompt
get_password() {
    local mode="$1"  # "encrypt" or "decrypt"
    
    if [ -z "$ENV_PASSWORD" ]; then
        echo -n "Enter password for $mode: " >&2
        read -s password
        echo >&2
        if [ -z "$password" ]; then
            echo -e "${RED}Error: Password cannot be empty${NC}" >&2
            return 1
        fi
    else
        password="$ENV_PASSWORD"
    fi
    echo "$password"
}

# Base64 decode (cross-platform)
base64_decode() {
    local data="$1"
    local output="$2"
    
    if echo "$data" | base64 -d > "$output" 2>/dev/null || \
       echo "$data" | base64 -D > "$output" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Process env file line by line
process_env_file() {
    local input_file="$1"
    local output_file="$2"
    local process_func="$3"  # Function to process each KEY=VALUE pair
    
    local temp_output=$(mktemp)
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            echo "$line" >> "$temp_output"
            continue
        fi
        
        # Check if line matches KEY=VALUE pattern
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Process the value
            local processed_value=$($process_func "$value")
            if [ $? -eq 0 ]; then
                echo "${key}=${processed_value}" >> "$temp_output"
            else
                echo "$line" >> "$temp_output"
            fi
        else
            # Line doesn't match KEY=VALUE pattern, keep as is
            echo "$line" >> "$temp_output"
        fi
    done < "$input_file"
    
    mv "$temp_output" "$output_file"
}

