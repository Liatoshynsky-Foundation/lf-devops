#!/bin/bash

# Encrypt .env files - encrypts only values, keeps keys unchanged
# Format: KEY=AES::@encrypted_value@
# Usage: ./scripts/encrypt-env.sh [filename]

set -e

# ============================================================================
# Configuration
# ============================================================================
# List of .env files to process
ENV_FILES=(.env .env.admin .env.client)

# ============================================================================
# Setup
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

source "$SCRIPT_DIR/env-crypto.sh"

# Encrypt a single value
encrypt_value() {
    local value="$1"
    local password="$2"

    [ -z "$value" ] && echo "" && return 0
    [[ "$value" =~ ^AES::@ ]] && echo "$value" && return 0  # Already encrypted

    local temp_input=$(mktemp) temp_encrypted=$(mktemp)
    echo -n "$value" > "$temp_input"

    if echo "$password" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 \
        -in "$temp_input" -out "$temp_encrypted" -pass stdin 2>/dev/null; then
        local base64_data=$(base64 < "$temp_encrypted" | tr -d '\n')
        echo "AES::@${base64_data}@"
        rm -f "$temp_input" "$temp_encrypted"
        return 0
    fi

    rm -f "$temp_input" "$temp_encrypted"
    return 1
}

# Encrypt a file (in-place, overwrites original)
encrypt_file() {
    local input_file="$1"
    local password="$2"  # Password passed as parameter
    local output_file="$input_file"  # Work in-place

    [ ! -f "$input_file" ] && echo -e "${RED}Error: $input_file not found${NC}" >&2 && return 1

    local temp_output=$(mktemp)
    local encrypted_count=0

    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && echo "$line" >> "$temp_output" && continue

        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}" value="${BASH_REMATCH[2]}"
            [[ "$value" =~ ^AES::@ ]] && echo "$line" >> "$temp_output" && continue

            local encrypted=$(encrypt_value "$value" "$password")
            if [ $? -eq 0 ]; then
                echo "${key}=${encrypted}" >> "$temp_output"
                ((encrypted_count++))
            else
                echo -e "${RED}✗ Failed to encrypt: $key${NC}" >&2
                rm -f "$temp_output"
                return 1
            fi
        else
            echo "$line" >> "$temp_output"
        fi
    done < "$input_file"

    mv "$temp_output" "$output_file"
    echo -e "${GREEN}✓ Encrypted: $input_file → $output_file (${encrypted_count} values)${NC}"
    return 0
}

# Main
# Get password once for all files
PASSWORD=$(get_password "encryption") || exit 1

if [ $# -eq 0 ]; then
    echo "Encrypting all .env files..."
    encrypted=0
    for file in "${ENV_FILES[@]}"; do
        if [ -f "$file" ]; then
            if encrypt_file "$file" "$PASSWORD"; then
                ((encrypted++))
            fi
        else
            echo -e "${YELLOW}Warning: $file not found, skipping${NC}" >&2
        fi
    done
    [ $encrypted -eq 0 ] && echo -e "${RED}No files encrypted${NC}" >&2 && exit 1
    echo -e "${GREEN}Successfully encrypted $encrypted file(s)${NC}"
else
    [[ ! "$1" =~ ^\.env(\.[a-zA-Z0-9_-]+)?$ ]] && \
        echo -e "${RED}Error: File must be .env or .env.* format${NC}" >&2 && exit 1
    encrypt_file "$1" "$PASSWORD"
fi
