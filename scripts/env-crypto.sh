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
    local mode="$1"

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

base64_decode() {
    local data="$1"
    local output="$2"

    if echo "$data" | base64 -d > "$output" 2>/dev/null || \
       echo "$data" | base64 -D > "$output" 2>/dev/null; then
        return 0
    fi
    return 1
}

process_env_file() {
    local input_file="$1"
    local output_file="$2"
    local process_func="$3"

    local temp_output=$(mktemp)

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            echo "$line" >> "$temp_output"
            continue
        fi

        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            local processed_value=$($process_func "$value")
            if [ $? -eq 0 ]; then
                echo "${key}=${processed_value}" >> "$temp_output"
            else
                echo "$line" >> "$temp_output"
            fi
        else
            echo "$line" >> "$temp_output"
        fi
    done < "$input_file"

    mv "$temp_output" "$output_file"
}

decrypt_value() {
    local encrypted_value="$1"
    local password="$2"

    [[ ! "$encrypted_value" =~ ^AES::@(.+)@$ ]] && echo "$encrypted_value" && return 0

    local base64_data="${BASH_REMATCH[1]}"
    local temp_encrypted=$(mktemp) temp_decrypted=$(mktemp)

    if base64_decode "$base64_data" "$temp_encrypted" && \
       echo "$password" | openssl enc -d -aes-256-cbc -pbkdf2 -iter 10000 \
           -in "$temp_encrypted" -out "$temp_decrypted" -pass stdin 2>/dev/null; then
        cat "$temp_decrypted"
        rm -f "$temp_encrypted" "$temp_decrypted"
        return 0
    fi

    rm -f "$temp_encrypted" "$temp_decrypted"
    return 1
}

encrypt_value() {
    local value="$1"
    local password="$2"

    [ -z "$value" ] && echo "" && return 0
    [[ "$value" =~ ^AES::@ ]] && echo "$value" && return 0

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

verify_password() {
    local input_file="$1"
    local password="$2"

    [ ! -f "$input_file" ] && return 0

    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local value="${BASH_REMATCH[2]}"

            if [[ "$value" =~ ^AES::@ ]]; then
                local test_decrypt=$(decrypt_value "$value" "$password" 2>/dev/null)
                local decrypt_status=$?
                if [ $decrypt_status -ne 0 ] || [ -z "$test_decrypt" ]; then
                    echo -e "${RED}Error: Incorrect password! Cannot decrypt values in $input_file${NC}" >&2
                    echo -e "${YELLOW}Please check your password and try again.${NC}" >&2
                    return 1
                fi
                return 0
            fi
        fi
    done < "$input_file"

    return 0
}
