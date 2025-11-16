#!/bin/bash

# Decrypt .env.enc files - decrypts only AES::@...@ values
# Format: KEY=AES::@encrypted_value@ → KEY=decrypted_value
# Usage: ./scripts/decrypt-env.sh [filename]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

source "$SCRIPT_DIR/env-crypto.sh"

# Decrypt a single value
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

# Decrypt a file (in-place, overwrites original)
decrypt_file() {
    local input_file="$1"
    local password="$2"  # Password passed as parameter
    local output_file="$input_file"  # Work in-place
    
    [ ! -f "$input_file" ] && echo -e "${RED}Error: $input_file not found${NC}" >&2 && return 1
    
    local temp_output=$(mktemp)
    local decrypted_count=0
    local errors=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && echo "$line" >> "$temp_output" && continue
        
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}" value="${BASH_REMATCH[2]}"
            
            if [[ "$value" =~ ^AES::@ ]]; then
                local decrypted=$(decrypt_value "$value" "$password")
                if [ $? -eq 0 ]; then
                    echo "${key}=${decrypted}" >> "$temp_output"
                    ((decrypted_count++))
                else
                    echo -e "${RED}✗ Failed to decrypt: $key${NC}" >&2
                    echo "$line" >> "$temp_output"
                    ((errors++))
                fi
            else
                echo "$line" >> "$temp_output"
            fi
        else
            echo "$line" >> "$temp_output"
        fi
    done < "$input_file"
    
    mv "$temp_output" "$output_file"
    
    if [ $errors -gt 0 ]; then
        echo -e "${RED}✗ Decrypted: $input_file → $output_file (${decrypted_count} values, ${errors} errors)${NC}" >&2
        return 1
    elif [ $decrypted_count -gt 0 ]; then
        echo -e "${GREEN}✓ Decrypted: $input_file → $output_file (${decrypted_count} values)${NC}"
        return 0
    else
        echo -e "${YELLOW}Warning: No encrypted values in $input_file${NC}" >&2
        return 0
    fi
}

# Main
ENV_FILES=(.env .env.admin .env.client)

# Get password once for all files
PASSWORD=$(get_password "decryption") || exit 1

if [ $# -eq 0 ]; then
    echo "Decrypting all .env files..."
    decrypted=0
    for file in "${ENV_FILES[@]}"; do
        if [ -f "$file" ]; then
            if decrypt_file "$file" "$PASSWORD"; then
                ((decrypted++))
            fi
        else
            echo -e "${YELLOW}Warning: $file not found, skipping${NC}" >&2
        fi
    done
    [ $decrypted -eq 0 ] && echo -e "${RED}No files decrypted${NC}" >&2 && exit 1
    echo -e "${GREEN}Successfully decrypted $decrypted file(s)${NC}"
else
    [[ ! "$1" =~ ^\.env(\.[a-zA-Z0-9_-]+)?$ ]] && \
        echo -e "${RED}Error: File must be .env or .env.* format${NC}" >&2 && exit 1
    decrypt_file "$1" "$PASSWORD"
fi
