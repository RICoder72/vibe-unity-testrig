#!/bin/bash

# claude-compile-check-v3.sh - Simplified Unity compilation checker
# Uses the new unified status system in .vibe-unity/compilation/
#
# Exit Codes:
#   0 = Success (no compilation errors)
#   1 = Compilation errors found
#   2 = Unity not accessible or timeout
#
# Usage: ./claude-compile-check-v3.sh

SCRIPT_VERSION="3.0.0"
PROJECT_NAME=""
PROJECT_HASH=""
STATUS_FILE=".vibe-unity/compilation/current-status.json"
HASH_FILE=".vibe-unity/compilation/project-hash.txt"
COMMAND_DIR=".vibe-unity/compilation/command-queue"

# Function to output structured results
output_result() {
    local status="$1"
    local error_count="$2"
    local warning_count="$3"
    local details="$4"
    
    echo "STATUS: $status"
    echo "ERRORS: $error_count"
    echo "WARNINGS: $warning_count"
    if [[ -n "$details" ]]; then
        echo "DETAILS:"
        echo "$details"
    fi
    echo "SCRIPT_VERSION: $SCRIPT_VERSION"
}

# Function to detect project name
detect_project_name() {
    PROJECT_NAME=$(basename "$(pwd)")
    echo "Project: $PROJECT_NAME" >&2
}

# Function to read project hash
read_project_hash() {
    if [[ -f "$HASH_FILE" ]]; then
        PROJECT_HASH=$(cat "$HASH_FILE")
        echo "Project hash: $PROJECT_HASH" >&2
    else
        echo "ERROR: Project hash file not found. Ensure Unity has compiled at least once." >&2
        output_result "ERROR" "0" "0" "Unity compilation system not initialized"
        exit 2
    fi
}

# Function to trigger compilation
trigger_compilation() {
    mkdir -p "$COMMAND_DIR"
    local request_id="bash-$(date +%s)"
    local command_file="$COMMAND_DIR/compile-$request_id.json"
    
    cat > "$command_file" << EOF
{
    "action": "force-compile",
    "requestId": "$request_id",
    "timestamp": $(date +%s)000
}
EOF
    echo "Compilation triggered (request: $request_id)" >&2
}

# Function to focus Unity window
focus_unity() {
    powershell.exe -Command "
    \$unityProcesses = Get-Process -Name 'Unity' -ErrorAction SilentlyContinue | Where-Object { \$_.MainWindowTitle -ne '' };
    \$targetUnity = \$null;
    
    # First priority: Find window with exact project name
    \$targetUnity = \$unityProcesses | Where-Object { \$_.MainWindowTitle -like '*$PROJECT_NAME*' } | Select-Object -First 1;
    
    # Second priority: Find window with project hash in the title
    if (-not \$targetUnity) {
        \$targetUnity = \$unityProcesses | Where-Object { \$_.MainWindowTitle -like '*$PROJECT_HASH*' } | Select-Object -First 1;
    }
    
    # Last resort: Ask user to specify
    if (-not \$targetUnity -and \$unityProcesses) {
        Write-Host 'Multiple Unity instances found:' -ForegroundColor Yellow;
        for (\$i = 0; \$i -lt \$unityProcesses.Count; \$i++) {
            Write-Host \"  [\$i] \$((\$unityProcesses[\$i]).MainWindowTitle)\" -ForegroundColor Yellow;
        }
        Write-Host 'Please close other Unity instances or ensure $PROJECT_NAME is in the window title' -ForegroundColor Red;
        \$targetUnity = \$unityProcesses | Select-Object -First 1;
    }
    
    \$unity = \$targetUnity;
    if (\$unity) {
        Add-Type -AssemblyName Microsoft.VisualBasic;
        [Microsoft.VisualBasic.Interaction]::AppActivate(\$unity.Id);
        Start-Sleep -Milliseconds 500;
        Add-Type -AssemblyName System.Windows.Forms;
        # Handle potential reload dialog by pressing Enter
        [System.Windows.Forms.SendKeys]::SendWait('{ENTER}');
        Start-Sleep -Milliseconds 200;
        # Now trigger force recompile
        [System.Windows.Forms.SendKeys]::SendWait('^+u');
        Write-Host \"Unity focused: \$((\$unity).MainWindowTitle)\" -ForegroundColor Green;
        Write-Host \"Force recompile triggered (Ctrl+Shift+U)\" -ForegroundColor Green;
    } else {
        Write-Host 'Unity not found' -ForegroundColor Red;
        exit 1
    }" 2>/dev/null
    return $?
}

# Function to wait for compilation result
wait_for_result() {
    local timeout=30
    local elapsed=0
    local last_timestamp=0
    
    # Get initial timestamp if file exists
    if [[ -f "$STATUS_FILE" ]]; then
        last_timestamp=$(grep -o '"timestamp":[0-9]*' "$STATUS_FILE" | cut -d':' -f2)
    fi
    
    echo "Waiting for compilation to complete..." >&2
    
    while [[ $elapsed -lt $timeout ]]; do
        if [[ -f "$STATUS_FILE" ]]; then
            local current_timestamp=$(grep -o '"timestamp":[0-9]*' "$STATUS_FILE" | cut -d':' -f2)
            
            # Check if timestamp changed
            if [[ "$current_timestamp" != "$last_timestamp" ]]; then
                local status=$(grep -o '"status":"[^"]*"' "$STATUS_FILE" | cut -d'"' -f4)
                
                # If status is not compiling, we have a result
                if [[ "$status" != "compiling" ]]; then
                    echo "Compilation complete (status: $status)" >&2
                    
                    # Parse the results
                    local errors=$(grep -o '"errors":[0-9]*' "$STATUS_FILE" | cut -d':' -f2)
                    local warnings=$(grep -o '"warnings":[0-9]*' "$STATUS_FILE" | cut -d':' -f2)
                    
                    # Extract details if there are errors
                    local details=""
                    if [[ $errors -gt 0 ]]; then
                        # Use python to parse JSON array if available
                        if command -v python3 >/dev/null 2>&1; then
                            details=$(python3 -c "
import json
with open('$STATUS_FILE') as f:
    data = json.load(f)
    if 'details' in data:
        for detail in data['details']:
            print('  ' + detail)
" 2>/dev/null)
                        fi
                    fi
                    
                    # Output results
                    if [[ "$status" == "error" ]] || [[ $errors -gt 0 ]]; then
                        output_result "ERROR" "$errors" "$warnings" "$details"
                        return 1
                    else
                        output_result "SUCCESS" "$errors" "$warnings" ""
                        return 0
                    fi
                fi
                
                last_timestamp="$current_timestamp"
            fi
        fi
        
        sleep 1
        ((elapsed++))
    done
    
    echo "Timeout waiting for compilation result" >&2
    output_result "TIMEOUT" "0" "0" "Unity did not complete compilation within $timeout seconds"
    return 2
}

# Main execution
main() {
    # Step 1: Detect project name
    detect_project_name
    
    # Step 2: Read project hash
    read_project_hash
    
    # Step 3: Focus Unity and trigger refresh
    if ! focus_unity; then
        output_result "ERROR" "0" "0" "Failed to focus Unity. Ensure Unity is running."
        exit 2
    fi
    
    # Step 4: Trigger compilation
    trigger_compilation
    
    # Step 5: Wait for result
    wait_for_result
    local result=$?
    
    exit $result
}

# Execute main function
main "$@"