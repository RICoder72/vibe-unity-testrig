#\!/bin/bash

# claude-compile-check-v2.sh - Unity compilation validator using Unity's internal status system
# 
# Purpose: Validates Unity C# script compilation by leveraging Unity's CompilationPipeline events
# Returns structured output with error/warning details from Unity's internal detection
#
# Exit Codes:
#   0 = Success (no compilation errors)
#   1 = Compilation errors found
#   2 = Timeout or Unity not accessible
#   3 = Script execution error
#
# Usage: ./claude-compile-check-v2.sh [--include-warnings]

INCLUDE_WARNINGS=false
SCRIPT_VERSION="2.0.0"
PROJECT_NAME=""
PROJECT_HASH=""
REQUEST_ID=""
DEBUG_MODE=${DEBUG_MODE:-false}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --include-warnings)
            INCLUDE_WARNINGS=true
            shift
            ;;
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--include-warnings] [--debug]"
            echo "Validates Unity compilation using Unity's internal status system"
            echo ""
            echo "Options:"
            echo "  --include-warnings  Include warning details in output"
            echo "  --debug             Keep status files for debugging"
            echo "  --help, -h          Show this help message"
            echo ""
            echo "Exit codes:"
            echo "  0 = Success (no errors)"
            echo "  1 = Compilation errors found"
            echo "  2 = Timeout/Unity not found"
            echo "  3 = Script execution error"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option $1" >&2
            echo "Use --help for usage information" >&2
            exit 3
            ;;
    esac
done

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

# Function to detect project name from current directory
detect_project_name() {
    local current_dir=$(pwd)
    PROJECT_NAME=$(basename "$current_dir")
    [[ "$DEBUG_MODE" == "true" ]] && echo "[DEBUG] Detected project name: $PROJECT_NAME" >&2
}

# Function to get project hash (matching Unity's hash generation)
get_project_hash() {
    local project_path="$(pwd)/Assets"
    # Unity uses the absolute path hash - we need to match it exactly
    # Unity's VibeUnityCompilationController uses GetHashCode on Application.dataPath
    # For now, we'll read it from an existing status file or use a fallback
    
    # Try to find the hash from existing files
    if [[ -d ".vibe-unity/compile-status" ]]; then
        local existing_file=$(ls -t .vibe-unity/compile-status/compile-status-*.json 2>/dev/null | head -1)
        if [[ -n "$existing_file" ]]; then
            PROJECT_HASH=$(grep -o '"project_hash":"[^"]*"' "$existing_file" | cut -d'"' -f4)
            [[ "$DEBUG_MODE" == "true" ]] && echo "[DEBUG] Found project hash from existing file: $PROJECT_HASH" >&2
        fi
    fi
    
    # Fallback: generate a predictable hash
    if [[ -z "$PROJECT_HASH" ]]; then
        # Use the project path to generate a hash (this may not match Unity's exactly)
        PROJECT_HASH=$(echo -n "$project_path" | md5sum | cut -c1-8 | tr '[:lower:]' '[:upper:]')
        echo "[WARNING] Generated project hash may not match Unity's: $PROJECT_HASH" >&2
    fi
}

# Function to generate unique request ID
generate_request_id() {
    if command -v uuidgen >/dev/null 2>&1; then
        REQUEST_ID="compile-$(uuidgen | tr '[:upper:]' '[:lower:]' | cut -c1-8)"
    else
        REQUEST_ID="compile-$(date +%s)-$$"
    fi
    [[ "$DEBUG_MODE" == "true" ]] && echo "[DEBUG] Request ID: $REQUEST_ID" >&2
}

# Function to send compile command to Unity
send_compile_command() {
    local action="$1"
    local commands_dir=".vibe-unity/compile-commands"
    
    # Ensure directory exists
    mkdir -p "$commands_dir"
    
    # Create command file
    local command_file="$commands_dir/compile-request-${PROJECT_HASH}-${REQUEST_ID}.json"
    cat > "$command_file" << EOCMD
{
    "action": "$action",
    "request_id": "$REQUEST_ID",
    "timestamp": $(date +%s)000
}
EOCMD
    echo "Command sent to Unity: $action" >&2
    [[ "$DEBUG_MODE" == "true" ]] && echo "[DEBUG] Command file: $command_file" >&2
}

# Function to read Unity's compilation status
read_unity_status() {
    local status_dir=".vibe-unity/compile-status"
    local status_file="$status_dir/compile-status-${REQUEST_ID}.json"
    local timeout=60
    local elapsed=0
    local last_status=""
    
    echo "Waiting for Unity compilation status..." >&2
    
    while [[ $elapsed -lt $timeout ]]; do
        if [[ -f "$status_file" ]]; then
            # Read the status file
            local content=$(cat "$status_file" 2>/dev/null)
            
            if [[ -z "$content" ]]; then
                # File exists but empty, Unity may still be writing
                sleep 0.5
                continue
            fi
            
            # Parse status
            local status=$(echo "$content" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            
            # Only print status change
            if [[ "$status" != "$last_status" ]]; then
                echo "Unity status: $status" >&2
                last_status="$status"
            fi
            
            if [[ "$status" == "complete" ]] || [[ "$status" == "error" ]]; then
                # Parse error and warning counts
                local errors=$(echo "$content" | grep -o '"errors":[0-9]*' | cut -d':' -f2)
                local warnings=$(echo "$content" | grep -o '"warnings":[0-9]*' | cut -d':' -f2)
                
                # Parse details if present
                local details=""
                if echo "$content" | grep -q '"details":\['; then
                    # Extract and format details array
                    details=$(echo "$content" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'details' in data and data['details']:
        for detail in data['details']:
            print('  ' + detail)
except:
    pass
" 2>/dev/null)
                    
                    # Fallback if python fails
                    if [[ -z "$details" ]]; then
                        details=$(echo "$content" | sed -n 's/.*"details":\[\([^]]*\)\].*/\1/p' | sed 's/"//g' | sed 's/,/\n  /g')
                    fi
                fi
                
                echo "Compilation complete - Errors: $errors, Warnings: $warnings" >&2
                
                # Include warnings in details if requested
                if [[ "$INCLUDE_WARNINGS" == "true" ]] && [[ -n "$details" ]]; then
                    output_result "$(echo $status | tr '[:lower:]' '[:upper:]')" "$errors" "$warnings" "$details"
                elif [[ $errors -gt 0 ]]; then
                    # Only show error details
                    local error_details=$(echo "$details" | grep -E "ERROR|error" || echo "$details")
                    output_result "$(echo $status | tr '[:lower:]' '[:upper:]')" "$errors" "$warnings" "$error_details"
                else
                    output_result "SUCCESS" "$errors" "$warnings" ""
                fi
                
                # Clean up files if not in debug mode
                if [[ "$DEBUG_MODE" != "true" ]]; then
                    rm -f "$status_file"
                    rm -f "$commands_dir/compile-request-${PROJECT_HASH}-${REQUEST_ID}.json"
                else
                    echo "[DEBUG] Status file kept: $status_file" >&2
                fi
                
                # Return appropriate exit code
                if [[ $errors -gt 0 ]]; then
                    return 1
                else
                    return 0
                fi
            elif [[ "$status" == "compiling" ]] || [[ "$status" == "processing" ]]; then
                # Unity is still processing
                :
            fi
        else
            # Check if Unity needs more prompting
            if [[ $elapsed -eq 5 ]] || [[ $elapsed -eq 10 ]]; then
                echo "Still waiting for Unity response..." >&2
                # Try to trigger Unity refresh again
                trigger_unity_refresh
            fi
        fi
        
        sleep 1
        ((elapsed++))
    done
    
    echo "Timeout waiting for Unity status response" >&2
    output_result "TIMEOUT" "0" "0" "Unity did not respond within $timeout seconds. Ensure Unity is running and the VibeUnity package is installed."
    return 2
}

# Function to focus Unity window
focus_unity() {
    local project_pattern="$PROJECT_NAME"
    
    if [[ -z "$project_pattern" ]]; then
        project_pattern="Unity"
    fi
    
    powershell.exe -Command "
    \$unityProcesses = Get-Process -Name 'Unity' -ErrorAction SilentlyContinue | Where-Object { \$_.MainWindowTitle -ne '' };
    \$targetUnity = \$null;
    
    if ('$project_pattern' -ne 'Unity') {
        \$targetUnity = \$unityProcesses | Where-Object { \$_.MainWindowTitle -like '*$project_pattern*' } | Select-Object -First 1;
    }
    
    if (-not \$targetUnity -and \$unityProcesses) {
        \$targetUnity = \$unityProcesses | Select-Object -First 1;
    }
    
    if (\$targetUnity) {
        Add-Type -AssemblyName Microsoft.VisualBasic;
        [Microsoft.VisualBasic.Interaction]::AppActivate(\$targetUnity.Id);
        Write-Host \"Unity focused: \$((\$targetUnity).MainWindowTitle)\";
    } else {
        Write-Host 'No Unity process found' -ForegroundColor Red;
        exit 1
    }" 2>/dev/null
    
    return $?
}

# Function to trigger Unity refresh
trigger_unity_refresh() {
    [[ "$DEBUG_MODE" == "true" ]] && echo "[DEBUG] Triggering Unity asset refresh..." >&2
    
    powershell.exe -Command "
    \$unity = Get-Process -Name 'Unity' -ErrorAction SilentlyContinue | 
              Where-Object { \$_.MainWindowTitle -like '*${PROJECT_NAME}*' } | 
              Select-Object -First 1;
    
    if (\$unity) {
        Add-Type -AssemblyName System.Windows.Forms;
        [System.Windows.Forms.SendKeys]::SendWait('^r');
        Start-Sleep -Milliseconds 100;
        [System.Windows.Forms.SendKeys]::SendWait('{F5}');
    }" 2>/dev/null
}

# Function to focus back to terminal
focus_terminal() {
    powershell.exe -Command "
    \$terminal = Get-Process -Name 'WindowsTerminal','cmd','powershell' -ErrorAction SilentlyContinue | 
                 Where-Object { \$_.MainWindowTitle -ne '' } | Select-Object -First 1;
    if (\$terminal) {
        Add-Type -AssemblyName Microsoft.VisualBasic;
        [Microsoft.VisualBasic.Interaction]::AppActivate(\$terminal.Id);
    }" 2>/dev/null
}

# Main execution function
main() {
    # Step 1: Detect project name
    detect_project_name
    
    # Step 2: Get project hash
    get_project_hash
    
    # Step 3: Generate unique request ID
    generate_request_id
    
    # Step 4: Focus Unity
    if \! focus_unity; then
        output_result "ERROR" "0" "0" "Failed to focus Unity window. Ensure Unity is running with the project open."
        exit 2
    fi
    
    # Step 5: Send compile command to Unity
    send_compile_command "force-compile"
    
    # Step 6: Trigger Unity refresh as backup
    trigger_unity_refresh
    
    # Give Unity a moment to process the command
    sleep 2
    
    # Step 7: Read Unity's compilation status
    read_unity_status
    local result=$?
    
    # Step 8: Focus back to terminal
    focus_terminal
    
    exit $result
}

# Execute main function
main "$@"
