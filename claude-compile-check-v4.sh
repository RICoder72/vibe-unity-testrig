#!/bin/bash

# claude-compile-check-v4.sh - Unity compilation checker with configurable shortcuts
# Reads shortcuts from .vibe-unity/vibe-unity-settings.json
#
# Exit Codes:
#   0 = Success (no compilation errors) 
#   1 = Compilation errors found
#   2 = Unity not accessible or timeout

SCRIPT_VERSION="4.0.0"
STATUS_FILE=".vibe-unity/compilation/current-status.json"
SETTINGS_FILE=".vibe-unity/vibe-unity-settings.json"
PROJECT_NAME=""
SHORTCUT_CODE="%#u"  # Default: Ctrl+Shift+U

echo "Unity compilation checker v$SCRIPT_VERSION" >&2

# Function to read shortcut from settings file
read_shortcut_from_settings() {
    if [[ -f "$SETTINGS_FILE" ]]; then
        # Extract forceRecompile shortcut from JSON
        local shortcut=$(grep -o '"forceRecompile":"[^"]*"' "$SETTINGS_FILE" | cut -d'"' -f4)
        if [[ -n "$shortcut" ]]; then
            SHORTCUT_CODE="$shortcut"
            echo "Using configured shortcut: $(convert_shortcut_to_description "$shortcut")" >&2
        else
            echo "No shortcut found in settings, using default: Ctrl+Shift+U" >&2
        fi
    else
        echo "Settings file not found, using default shortcut: Ctrl+Shift+U" >&2
    fi
}

# Function to convert Unity shortcut code to human description
convert_shortcut_to_description() {
    local code="$1"
    local desc=""
    
    if [[ "$code" == *"%"* ]]; then
        desc+="Ctrl+"
    fi
    
    if [[ "$code" == *"#"* ]]; then
        desc+="Shift+"
    fi
    
    if [[ "$code" == *"&"* ]]; then
        desc+="Alt+"
    fi
    
    # Get the key (last character)
    local key="${code: -1}"
    desc+="$(echo $key | tr '[:lower:]' '[:upper:]')"
    
    echo "$desc"
}

# Function to convert Unity shortcut code to SendKeys format
convert_shortcut_to_sendkeys() {
    local code="$1"
    local sendkeys=""
    
    # Build modifier string
    if [[ "$code" == *"%"* ]]; then
        sendkeys+="^"  # Ctrl
    fi
    
    if [[ "$code" == *"#"* ]]; then
        sendkeys+="+"  # Shift  
    fi
    
    if [[ "$code" == *"&"* ]]; then
        sendkeys+="%"  # Alt (% in SendKeys, confusing but correct)
    fi
    
    # Add the key
    local key="${code: -1}"
    sendkeys+="$key"
    
    echo "$sendkeys"
}

# Function to detect project name
detect_project_name() {
    PROJECT_NAME=$(basename "$(pwd)")
    echo "Project: $PROJECT_NAME" >&2
}

# Function to focus Unity window and send shortcut
focus_unity_and_compile() {
    local sendkeys_code=$(convert_shortcut_to_sendkeys "$SHORTCUT_CODE")
    local description=$(convert_shortcut_to_description "$SHORTCUT_CODE")
    
    powershell.exe -Command "
    \$unityProcesses = Get-Process -Name 'Unity' -ErrorAction SilentlyContinue | Where-Object { \$_.MainWindowTitle -ne '' };
    \$targetUnity = \$null;
    
    # Find Unity window with project name
    \$targetUnity = \$unityProcesses | Where-Object { \$_.MainWindowTitle -like '*$PROJECT_NAME*' } | Select-Object -First 1;
    
    if (-not \$targetUnity -and \$unityProcesses) {
        Write-Host 'Multiple Unity instances found, using first one' -ForegroundColor Yellow;
        \$targetUnity = \$unityProcesses | Select-Object -First 1;
    }
    
    if (\$targetUnity) {
        Add-Type -AssemblyName Microsoft.VisualBasic;
        [Microsoft.VisualBasic.Interaction]::AppActivate(\$targetUnity.Id);
        Start-Sleep -Milliseconds 500;
        
        Add-Type -AssemblyName System.Windows.Forms;
        # Handle potential reload dialog
        [System.Windows.Forms.SendKeys]::SendWait('{ENTER}');
        Start-Sleep -Milliseconds 200;
        
        # Send the configured shortcut
        [System.Windows.Forms.SendKeys]::SendWait('$sendkeys_code');
        Write-Host \"Unity focused: \$((\$targetUnity).MainWindowTitle)\" -ForegroundColor Green;
        Write-Host \"Compilation triggered: $description\" -ForegroundColor Green;
    } else {
        Write-Host 'Unity not found' -ForegroundColor Red;
        exit 1
    }" 2>/dev/null
    
    return $?
}

# Function to read compilation status
read_compilation_status() {
    if [[ ! -f "$STATUS_FILE" ]]; then
        echo "STATUS: ERROR"
        echo "ERRORS: 0" 
        echo "WARNINGS: 0"
        echo "DETAILS: Unity compilation system not initialized"
        echo "SCRIPT_VERSION: $SCRIPT_VERSION"
        exit 2
    fi
    
    # Wait a moment for Unity to update status
    sleep 2
    
    # Read status from JSON
    local status=$(grep -o '"status": *"[^"]*"' "$STATUS_FILE" | cut -d'"' -f4)
    local errors=$(grep -o '"errors": *[0-9]*' "$STATUS_FILE" | sed 's/.*: *//')
    local warnings=$(grep -o '"warnings": *[0-9]*' "$STATUS_FILE" | sed 's/.*: *//')
    
    # Extract details if there are errors
    local details=""
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
}

# Main execution
main() {
    detect_project_name
    read_shortcut_from_settings
    
    # Focus Unity and trigger compilation
    if focus_unity_and_compile; then
        read_compilation_status
    else
        echo "STATUS: ERROR"
        echo "ERRORS: 0"
        echo "WARNINGS: 0"
        echo "DETAILS: Failed to focus Unity. Ensure Unity is running."
        echo "SCRIPT_VERSION: $SCRIPT_VERSION"
        exit 2
    fi
}

main "$@"