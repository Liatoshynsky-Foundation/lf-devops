#!/bin/bash

# Edit encrypted .env files - decrypts, allows editing, re-encrypts
# Usage: ./scripts/edit-env.sh [filename] [KEY=value]
#   Without KEY=value: opens file in editor
#   With KEY=value: sets the value directly

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

source "$SCRIPT_DIR/env-crypto.sh"

# Determine editor
EDITOR="${EDITOR:-${VISUAL:-nano}}"

# Edit a file interactively
edit_file_interactive() {
    local file="$1"
    local password="$2"
    local temp_decrypted=$(mktemp)

    # Decrypt to temp file
    if ! decrypt_file_to_temp "$file" "$password" "$temp_decrypted"; then
        rm -f "$temp_decrypted"
        return 1
    fi

    # Get original modification time
    local original_mtime=$(stat -f "%m" "$temp_decrypted" 2>/dev/null || stat -c "%Y" "$temp_decrypted" 2>/dev/null || echo "0")

    # Edit the file
    $EDITOR "$temp_decrypted"

    # Check if file was modified
    local new_mtime=$(stat -f "%m" "$temp_decrypted" 2>/dev/null || stat -c "%Y" "$temp_decrypted" 2>/dev/null || echo "0")

    if [ "$original_mtime" = "$new_mtime" ]; then
        echo -e "${YELLOW}No changes made, skipping re-encryption${NC}"
        rm -f "$temp_decrypted"
        return 0
    fi

    # Re-encrypt
    if ! encrypt_file_from_temp "$temp_decrypted" "$file" "$password"; then
        rm -f "$temp_decrypted"
        return 1
    fi

    rm -f "$temp_decrypted"
    echo -e "${GREEN}✓ File edited and re-encrypted: $file${NC}"
    return 0
}

# Set a specific key-value pair
set_value() {
    local file="$1"
    local key_value="$2"
    local password="$3"
    local temp_decrypted=$(mktemp)

    # Parse KEY=value
    if [[ ! "$key_value" =~ ^([^=]+)=(.*)$ ]]; then
        echo -e "${RED}Error: Invalid format. Use KEY=value${NC}" >&2
        rm -f "$temp_decrypted"
        return 1
    fi

    local key="${BASH_REMATCH[1]}"
    local new_value="${BASH_REMATCH[2]}"

    # Decrypt to temp file
    if ! decrypt_file_to_temp "$file" "$password" "$temp_decrypted"; then
        rm -f "$temp_decrypted"
        return 1
    fi

    # Update or add the key
    local temp_updated=$(mktemp)
    local key_found=0

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local current_key="${BASH_REMATCH[1]}"
            if [ "$current_key" = "$key" ]; then
                echo "${key}=${new_value}" >> "$temp_updated"
                key_found=1
            else
                echo "$line" >> "$temp_updated"
            fi
        else
            echo "$line" >> "$temp_updated"
        fi
    done < "$temp_decrypted"

    # Add key if not found
    if [ $key_found -eq 0 ]; then
        echo "${key}=${new_value}" >> "$temp_updated"
        echo -e "${YELLOW}Key '$key' not found, adding new entry${NC}"
    else
        echo -e "${GREEN}Updated key: $key${NC}"
    fi

    # Re-encrypt
    if ! encrypt_file_from_temp "$temp_updated" "$file" "$password"; then
        rm -f "$temp_decrypted" "$temp_updated"
        return 1
    fi

    rm -f "$temp_decrypted" "$temp_updated"
    echo -e "${GREEN}✓ Value set and file re-encrypted: $file${NC}"
    return 0
}

# Decrypt file to temporary location (non-destructive)
decrypt_file_to_temp() {
    local input_file="$1"
    local password="$2"
    local output_file="$3"

    [ ! -f "$input_file" ] && echo -e "${RED}Error: $input_file not found${NC}" >&2 && return 1

    # Verify password first
    if ! verify_password "$input_file" "$password"; then
        return 1
    fi

    local temp_output=$(mktemp)

    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && echo "$line" >> "$temp_output" && continue

        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}" value="${BASH_REMATCH[2]}"

            if [[ "$value" =~ ^AES::@ ]]; then
                local decrypted=$(decrypt_value "$value" "$password")
                if [ $? -eq 0 ]; then
                    echo "${key}=${decrypted}" >> "$temp_output"
                else
                    echo -e "${RED}✗ Failed to decrypt: $key${NC}" >&2
                    rm -f "$temp_output"
                    return 1
                fi
            else
                echo "$line" >> "$temp_output"
            fi
        else
            echo "$line" >> "$temp_output"
        fi
    done < "$input_file"

    mv "$temp_output" "$output_file"
    return 0
}

# Encrypt file from temporary location
encrypt_file_from_temp() {
    local input_file="$1"
    local output_file="$2"
    local password="$3"

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
    return 0
}

# Main
ENV_FILES=(.env .env.admin .env.client)

# Get password once
PASSWORD=$(get_password "decryption") || exit 1

if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage:${NC}"
    echo "  $0 <file>                    - Edit file interactively"
    echo "  $0 <file> KEY=value          - Set specific key-value pair"
    echo ""
    echo "Available files: ${ENV_FILES[*]}"
    exit 1
elif [ $# -eq 1 ]; then
    # Interactive edit
    local file="$1"
    [[ ! "$file" =~ ^\.env(\.[a-zA-Z0-9_-]+)?$ ]] && \
        echo -e "${RED}Error: File must be .env or .env.* format${NC}" >&2 && exit 1
    [ ! -f "$file" ] && echo -e "${RED}Error: $file not found${NC}" >&2 && exit 1
    edit_file_interactive "$file" "$PASSWORD"
elif [ $# -eq 2 ]; then
    # Set specific value
    local file="$1"
    local key_value="$2"
    [[ ! "$file" =~ ^\.env(\.[a-zA-Z0-9_-]+)?$ ]] && \
        echo -e "${RED}Error: File must be .env or .env.* format${NC}" >&2 && exit 1
    [ ! -f "$file" ] && echo -e "${RED}Error: $file not found${NC}" >&2 && exit 1
    set_value "$file" "$key_value" "$PASSWORD"
else
    echo -e "${RED}Error: Too many arguments${NC}" >&2
    exit 1
fi
