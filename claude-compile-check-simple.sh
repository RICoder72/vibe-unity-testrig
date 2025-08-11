#!/bin/bash

# claude-compile-check-simple.sh - Ultra-simplified Unity compilation checker
# Just triggers recompile and reads the final status
#
# Exit Codes:
#   0 = Success (no compilation errors) 
#   1 = Compilation errors found

SCRIPT_VERSION="3.1.0"
STATUS_FILE=".vibe-unity/compilation/current-status.json"
HASH_FILE=".vibe-unity/compilation/project-hash.txt"

echo "Reading Unity compilation status..." >&2

# Check if Unity system is initialized
if [[ ! -f "$STATUS_FILE" ]]; then
    echo "STATUS: ERROR"
    echo "ERRORS: 0"
    echo "WARNINGS: 0"
    echo "DETAILS: Unity compilation system not initialized"
    echo "SCRIPT_VERSION: $SCRIPT_VERSION"
    exit 2
fi

# Read current status (JSON has spaces around colons)
status=$(grep -o '"status": *"[^"]*"' "$STATUS_FILE" | cut -d'"' -f4)
errors=$(grep -o '"errors": *[0-9]*' "$STATUS_FILE" | sed 's/.*: *//')
warnings=$(grep -o '"warnings": *[0-9]*' "$STATUS_FILE" | sed 's/.*: *//')

# Format details if there are errors
details=""
if [[ $errors -gt 0 ]]; then
    if command -v python3 >/dev/null 2>&1; then
        details=$(python3 -c "
import json
try:
    with open('$STATUS_FILE') as f:
        data = json.load(f)
        if 'details' in data and data['details']:
            for detail in data['details']:
                print('  ' + detail)
except:
    pass
" 2>/dev/null)
    fi
fi

echo "STATUS: $(echo $status | tr '[:lower:]' '[:upper:]')"
echo "ERRORS: $errors"
echo "WARNINGS: $warnings"
if [[ -n "$details" ]]; then
    echo "DETAILS:"
    echo "$details"
fi
echo "SCRIPT_VERSION: $SCRIPT_VERSION"

# Return appropriate exit code
if [[ $errors -gt 0 ]]; then
    exit 1
else
    exit 0
fi