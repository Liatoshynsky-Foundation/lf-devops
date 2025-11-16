#!/bin/bash

# Check if .env files contain unencrypted secrets
# Exits with error if any KEY=VALUE pairs are not encrypted (not in AES::@...@ format)
# Usage: ./scripts/check-env-secrets.sh [filename]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

source "$SCRIPT_DIR/env-crypto.sh"

# Check a single file
check_file() {
    local file="$1"
    local errors=0
    
    [ ! -f "$file" ] && return 0
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Check if line matches KEY=VALUE pattern
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Check if value is NOT encrypted
            if [[ ! "$value" =~ ^AES::@ ]]; then
                echo -e "${RED}✗ Unencrypted secret found in $file: $key${NC}" >&2
                ((errors++))
            fi
        fi
    done < "$file"
    
    return $errors
}

# Main
ENV_FILES=(.env .env.admin .env.client)
total_errors=0

if [ $# -eq 0 ]; then
    echo "Checking .env files for unencrypted secrets..."
    for file in "${ENV_FILES[@]}"; do
        check_file "$file"
        total_errors=$((total_errors + $?))
    done
else
    check_file "$1"
    total_errors=$?
fi

if [ $total_errors -gt 0 ]; then
    echo -e "\n${RED}Error: Found $total_errors unencrypted secret(s)${NC}" >&2
    echo -e "${YELLOW}Please encrypt all secrets using: ./scripts/encrypt-env.sh${NC}" >&2
    exit 1
fi

echo -e "${GREEN}✓ All secrets are encrypted${NC}"
exit 0
