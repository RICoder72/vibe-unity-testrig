#!/bin/bash

# claude-compile-check-v2.sh - File-based Unity compilation validator for claude-code integration
# 
# Purpose: Validates Unity C# script compilation using file-based communication with Unity
# Provides hardened triggers, precise timing, and detailed error/warning reporting
#
# Exit Codes:
#   0 = Success (no compilation errors)
#   1 = Compilation errors found
#   2 = Timeout or Unity not accessible
#   3 = Script execution error

SCRIPT_VERSION="2.0.1"
INCLUDE_WARNINGS=false
TIMEOUT=45  # Increased for longer compilation times (like first-time compile)
RETRY_COUNT=0
MAX_RETRIES=2
POLL_INTERVAL=0.5
DEBUG_STATUS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --include-warnings)
            INCLUDE_WARNINGS=true
            shift
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --debug)
            DEBUG_STATUS=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--include-warnings] [--timeout SECONDS] [--debug]"
            echo "Validates Unity compilation using file-based communication"
            echo ""
            echo "Options:"
            echo "  --include-warnings  Include warning details in output"
            echo "  --timeout SECONDS   Compilation timeout in seconds (default: 45)"
            echo "  --debug             Enable debug status monitoring"
            echo "  --help, -h          Show this help message"
            echo ""
            echo "Exit codes:"
            echo "  0 = Success (no errors)"
            echo "  1 = Compilation errors found" 
            echo "  2 = Timeout/Unity communication failed"
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

# Setup paths
PROJECT_ROOT=$(pwd)
COMMANDS_DIR="$PROJECT_ROOT/.vibe-unity/compile-commands"
STATUS_DIR="$PROJECT_ROOT/.vibe-unity/compile-status"

# Ensure directories exist
mkdir -p "$COMMANDS_DIR"
mkdir -p "$STATUS_DIR"

# Function to generate unique request ID
generate_request_id() {
    echo "$(date +%s%3N)-$$-$(uuidgen | cut -d'-' -f1)"
}

# Function to detect project hash
detect_project_hash() {
    # Try to read project hash from existing status files
    local latest_status=$(find "$STATUS_DIR" -name "compile-status-*.json" -type f 2>/dev/null | sort -r | head -1)
    if [[ -n "$latest_status" && -f "$latest_status" ]]; then
        local project_hash=$(grep -o '"project_hash":"[^"]*"' "$latest_status" 2>/dev/null | cut -d'"' -f4)
        if [[ -n "$project_hash" ]]; then
            echo "$project_hash"
            return 0
        fi
    fi
    
    # For vibe-unity-testrig, use the known hash that Unity is using
    # This matches what Unity's Application.dataPath.GetHashCode() produces
    echo "5E88DFAB"
}

# Function to output structured results
output_result() {
    local status="$1"
    local errors="$2"
    local warnings="$3"
    local details="$4"
    local duration="$5"
    
    echo "STATUS: $status"
    echo "ERRORS: $errors"
    echo "WARNINGS: $warnings"
    
    if [[ -n "$details" && "$details" != "null" && "$details" != "[]" ]]; then
        echo "DETAILS:"
        echo "$details" | sed 's/^/  /'
    else
        echo "DETAILS:"
        case "$status" in
            "SUCCESS")
                if [[ -n "$duration" && "$duration" != "0" ]]; then
                    echo "  Compilation completed successfully in ${duration}ms"
                else
                    echo "  No compilation required - scripts are up to date"
                fi
                ;;
            "ERRORS")
                echo "  Compilation failed - check Unity Console for details"
                ;;
            "TIMEOUT")
                echo "  Compilation timed out after ${TIMEOUT} seconds"
                ;;
        esac
    fi
    
    echo "SCRIPT_VERSION: $SCRIPT_VERSION"
}

# Function to send compile command to Unity
send_compile_command() {
    local request_id="$1"
    local project_hash="$2"
    local timestamp=$(date +%s%3N)
    
    local command_file="$COMMANDS_DIR/compile-request-${project_hash}-${request_id}.json"
    
    cat > "$command_file" << EOF
{
    "action": "force-compile",
    "request_id": "$request_id",
    "timestamp": $timestamp
}
EOF
    
    if [[ $? -eq 0 ]]; then
        echo "Compile command sent: $request_id" >&2
        return 0
    else
        echo "Failed to write command file" >&2
        return 1
    fi
}

# Function to focus Unity window to ensure it processes file changes
focus_unity() {
    echo "Focusing Unity window to trigger file change detection..." >&2
    
    local focus_result=$(powershell.exe -Command "
    \$unity = Get-Process -Name 'Unity' -ErrorAction SilentlyContinue | 
              Where-Object { \$_.MainWindowTitle -like '*vibe-unity-testrig*' } | 
              Select-Object -First 1;
    
    if (\$unity) {
        Add-Type -AssemblyName Microsoft.VisualBasic;
        [Microsoft.VisualBasic.Interaction]::AppActivate(\$unity.Id);
        Write-Host 'Unity window focused for file detection';
        \$true;
    } else {
        Write-Host 'Unity window not found' -ForegroundColor Yellow;
        \$false;
    }" 2>/dev/null)
    
    # Parse the result
    if echo "$focus_result" | grep -q "Unity window focused"; then
        echo "✓ Unity focused successfully" >&2
        return 0
    else
        echo "✗ Failed to focus Unity" >&2
        return 1
    fi
}

# Function to wait for status response with improved timing
wait_for_status() {
    local request_id="$1"
    local start_time=$(date +%s)
    local status_file="$STATUS_DIR/compile-status-${request_id}.json"
    local compilation_detected=false
    local first_status=""
    
    echo "Waiting for compilation status (timeout: ${TIMEOUT}s)..." >&2
    
    while [[ $(($(date +%s) - start_time)) -lt $TIMEOUT ]]; do
        local elapsed=$(($(date +%s) - start_time))
        
        # Debug: Show what we're looking for every 5 seconds
        if [[ "$DEBUG_STATUS" == "true" && $((elapsed % 5)) -eq 0 && $elapsed -gt 0 ]]; then
            echo "Debug: ${elapsed}s elapsed, checking $status_file" >&2
            if [[ -f "$status_file" ]]; then
                echo "Debug: Status file exists, size: $(wc -c < "$status_file" 2>/dev/null || echo "0") bytes" >&2
            else
                echo "Debug: Status file does not exist yet" >&2
            fi
        fi
        
        if [[ -f "$status_file" ]]; then
            local json_content=$(cat "$status_file" 2>/dev/null)
            if [[ -n "$json_content" ]]; then
                local current_status=$(echo "$json_content" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
                
                # Track if we've seen Unity actually start compiling
                if [[ "$current_status" == "compiling" && "$compilation_detected" == "false" ]]; then
                    compilation_detected=true
                    echo "✓ Compilation started after ${elapsed}s" >&2
                elif [[ "$current_status" == "complete" ]]; then
                    if [[ "$compilation_detected" == "true" ]]; then
                        echo "✓ Compilation completed after ${elapsed}s" >&2
                        echo "$json_content"
                        return 0
                    else
                        echo "⚠ Unity reports 'complete' but we never saw it start compiling (${elapsed}s)" >&2
                        # Keep waiting a bit more to see if actual compilation starts
                        if [[ $elapsed -lt 5 ]]; then
                            sleep 1
                            continue
                        fi
                        # Accept the result but note the suspicious timing
                        echo "Accepting completion status (may not have needed compilation)" >&2
                        echo "$json_content"
                        return 0
                    fi
                elif [[ "$current_status" == "error" ]]; then
                    echo "✗ Compilation error after ${elapsed}s" >&2
                    echo "$json_content"
                    return 0
                fi
                
                # Store first status for debugging
                if [[ -z "$first_status" ]]; then
                    first_status="$current_status"
                    echo "First status: $current_status after ${elapsed}s" >&2
                fi
            fi
        fi
        sleep "$POLL_INTERVAL"
    done
    
    echo "Timeout waiting for status after ${TIMEOUT}s" >&2
    echo "Debug: compilation_detected=$compilation_detected, first_status=$first_status" >&2
    return 1
}

# Function to parse status JSON (simplified bash parsing)
parse_status_json() {
    local json="$1"
    
    # Extract key values using grep and sed
    local status=$(echo "$json" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    local errors=$(echo "$json" | grep -o '"errors":[0-9]*' | cut -d':' -f2)
    local warnings=$(echo "$json" | grep -o '"warnings":[0-9]*' | cut -d':' -f2)
    local duration=$(echo "$json" | grep -o '"duration_ms":[0-9]*' | cut -d':' -f2)
    
    # Extract details array (simplified)
    local details=""
    if echo "$json" | grep -q '"details":\['; then
        details=$(echo "$json" | sed -n 's/.*"details":\[\([^]]*\)\].*/\1/p' | sed 's/",""/\n/g' | sed 's/^"//;s/"$//')
        # Clean up the details formatting
        if [[ -n "$details" && "$details" != "null" ]]; then
            details=$(echo "$details" | sed 's/\\n/\n/g' | sed 's/\\"//g')
            # Only include warnings if requested
            if [[ "$INCLUDE_WARNINGS" != "true" ]]; then
                details=$(echo "$details" | grep -v "WARNING" || true)
            fi
        fi
    fi
    
    # Default values if not found
    status=${status:-"unknown"}
    errors=${errors:-"0"}
    warnings=${warnings:-"0"}
    duration=${duration:-"0"}
    
    echo "$status|$errors|$warnings|$details|$duration"
}

# Function to cleanup old files
cleanup_old_files() {
    # Clean up command files older than 1 minute
    find "$COMMANDS_DIR" -name "*.json" -type f -mmin +1 2>/dev/null | xargs rm -f 2>/dev/null || true
    
    # Clean up status files older than 5 minutes  
    find "$STATUS_DIR" -name "*.json" -type f -mmin +5 2>/dev/null | xargs rm -f 2>/dev/null || true
}

# Main execution function
main() {
    local project_hash=$(detect_project_hash)
    local request_id=$(generate_request_id)
    
    echo "Unity compilation check v$SCRIPT_VERSION" >&2
    echo "Project hash: $project_hash" >&2
    echo "Request ID: $request_id" >&2
    
    # Clean up old files first
    cleanup_old_files
    
    # Send compile command to Unity
    if ! send_compile_command "$request_id" "$project_hash"; then
        output_result "ERROR" "0" "0" "Failed to send compile command to Unity"
        return 3
    fi
    
    echo "Command sent, giving Unity time to process..." >&2
    
    # CRITICAL: Give Unity time to detect file changes and process the command
    # Without this delay, we check compilation status before Unity realizes it needs to compile
    sleep 3
    
    # Focus Unity to ensure it processes file changes (Windows-specific timing issue)
    if focus_unity; then
        echo "Unity focused, continuing without returning focus to WSL (avoids hanging)" >&2
    else
        echo "Warning: Could not focus Unity, but continuing..." >&2
    fi
    
    # Give Unity additional time to start processing (especially important for first-time compilation)
    sleep 2
    
    echo "Starting status monitoring..." >&2
    
    # Wait for status response with improved timing detection
    local json_response=""
    if json_response=$(wait_for_status "$request_id"); then
        # Parse the response
        local parsed=$(parse_status_json "$json_response")
        local status=$(echo "$parsed" | cut -d'|' -f1)
        local errors=$(echo "$parsed" | cut -d'|' -f2)
        local warnings=$(echo "$parsed" | cut -d'|' -f3)
        local details=$(echo "$parsed" | cut -d'|' -f4)
        local duration=$(echo "$parsed" | cut -d'|' -f5)
        
        # Clean up status file
        rm -f "$STATUS_DIR/compile-status-${request_id}.json" 2>/dev/null || true
        
        # Output results
        case "$status" in
            "complete")
                if [[ "$errors" -eq 0 ]]; then
                    output_result "SUCCESS" "$errors" "$warnings" "$details" "$duration"
                    return 0
                else
                    output_result "ERRORS" "$errors" "$warnings" "$details" "$duration"
                    return 1
                fi
                ;;
            "compiling")
                output_result "TIMEOUT" "$errors" "$warnings" "Unity is still compiling" "$duration"
                return 2
                ;;
            "error")
                output_result "ERROR" "$errors" "$warnings" "$details" "$duration"
                return 3
                ;;
            *)
                output_result "ERROR" "0" "0" "Unknown status: $status"
                return 3
                ;;
        esac
    else
        output_result "TIMEOUT" "0" "0" "No response from Unity after ${TIMEOUT} seconds"
        return 2
    fi
}

# Handle script interruption
trap 'echo "Script interrupted" >&2; exit 3' INT TERM

# Execute main function
main "$@"
exit $?