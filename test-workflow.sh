#!/bin/bash

# Test workflow for vibe-unity development
# This script handles the complete testing process after code changes

UNITY_LOG_PATH="/mnt/c/Users/matth/AppData/Local/Unity/Editor/Editor.log"
TEST_FILE_PATH="/mnt/c/repos/vibe-unity-testrig/.vibe-commands/test-scene-creation.json"

# Function to focus Unity window
focus_unity() {
    echo "[Test Workflow] Focusing Unity window to trigger recompilation..."
    powershell.exe -Command "
    \$unity = Get-Process -Name 'Unity' -ErrorAction SilentlyContinue | Where-Object { \$_.MainWindowTitle -like '*vibe-unity-testrig*' } | Select-Object -First 1;
    if (\$unity) {
        Add-Type -AssemblyName Microsoft.VisualBasic;
        [Microsoft.VisualBasic.Interaction]::AppActivate(\$unity.Id);
        Write-Host 'Unity window focused for recompilation'
    } else {
        Write-Host 'Unity process with vibe-unity-testrig not found'
    }" 2>/dev/null
}

# Function to focus Ubuntu/WSL window  
focus_ubuntu() {
    echo "[Test Workflow] Focusing Ubuntu window..."
    powershell.exe -Command "
    \$wsl = Get-Process -Name 'WindowsTerminal' -ErrorAction SilentlyContinue | Select-Object -First 1;
    if (\$wsl) {
        Add-Type -AssemblyName Microsoft.VisualBasic;
        [Microsoft.VisualBasic.Interaction]::AppActivate(\$wsl.Id);
        Write-Host 'Ubuntu window focused'
    } else {
        Write-Host 'Windows Terminal not found, trying alternative...'
        \$cmd = Get-Process -Name 'cmd' -ErrorAction SilentlyContinue | Select-Object -First 1;
        if (\$cmd) {
            Add-Type -AssemblyName Microsoft.VisualBasic;
            [Microsoft.VisualBasic.Interaction]::AppActivate(\$cmd.Id);
            Write-Host 'Command window focused'
        }
    }" 2>/dev/null
}

# Function to monitor Unity compilation
monitor_compilation() {
    echo "[Test Workflow] Monitoring Unity compilation..."
    
    # Get current log size to track new entries
    if [ -f "$UNITY_LOG_PATH" ]; then
        INITIAL_SIZE=$(stat -c%s "$UNITY_LOG_PATH")
        echo "[Test Workflow] Starting log monitoring from position: $INITIAL_SIZE bytes"
    else
        echo "[Test Workflow] ERROR: Unity log file not found at $UNITY_LOG_PATH"
        return 1
    fi
    
    # Wait for compilation completion indicators
    TIMEOUT=30
    ELAPSED=0
    
    while [ $ELAPSED -lt $TIMEOUT ]; do
        # Check for compilation completion messages in new log entries
        if [ -f "$UNITY_LOG_PATH" ]; then
            CURRENT_SIZE=$(stat -c%s "$UNITY_LOG_PATH")
            if [ $CURRENT_SIZE -gt $INITIAL_SIZE ]; then
                # Get new log entries
                NEW_ENTRIES=$(tail -c +$((INITIAL_SIZE + 1)) "$UNITY_LOG_PATH")
                
                # Check for compilation completion indicators
                if echo "$NEW_ENTRIES" | grep -q "Reloading assemblies after forced synchronous recompile\|Finished compiling graph\|CompileScripts:.*ms\|Hotreload:.*ms\|PostProcessAllAssets:.*ms"; then
                    echo "[Test Workflow] ✅ Compilation/Hotreload completed!"
                    return 0
                fi
            fi
        fi
        
        sleep 1
        ELAPSED=$((ELAPSED + 1))
        
        # Show progress every 5 seconds
        if [ $((ELAPSED % 5)) -eq 0 ]; then
            echo "[Test Workflow] Still waiting for compilation... (${ELAPSED}s/${TIMEOUT}s)"
        fi
    done
    
    echo "[Test Workflow] ⚠️ Timeout waiting for compilation completion"
    return 1
}

# Function to run the test file
run_test() {
    echo "[Test Workflow] Running test file..."
    
    if [ ! -f "$TEST_FILE_PATH" ]; then
        echo "[Test Workflow] ERROR: Test file not found at $TEST_FILE_PATH"
        return 1
    fi
    
    echo "[Test Workflow] Processing: $(basename "$TEST_FILE_PATH")"
    
    # Create a timestamped copy to trigger file watcher
    TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
    TEMP_TEST_FILE="/mnt/c/repos/vibe-unity-testrig/.vibe-commands/manual-test-${TIMESTAMP}.json"
    
    echo "[Test Workflow] Creating test file to trigger file watcher..."
    cp "$TEST_FILE_PATH" "$TEMP_TEST_FILE"
    
    echo "[Test Workflow] Test file created: $(basename "$TEMP_TEST_FILE")"
    echo "[Test Workflow] File watcher should now process this file automatically..."
    
    # Wait a moment for Unity to process the file
    sleep 3
    
    echo "[Test Workflow] ✅ Test file processing initiated"
    echo "[Test Workflow] Check Unity Console for processing results"
    
    return 0
}

# Main workflow function
run_test_workflow() {
    echo "=================================="
    echo "[Test Workflow] Starting complete test workflow"
    echo "=================================="
    
    # Step 1: Focus Unity to trigger recompilation
    focus_unity
    sleep 2
    
    # Step 2: Focus Ubuntu to return control
    focus_ubuntu
    sleep 1
    
    # Step 3: Monitor compilation completion
    if monitor_compilation; then
        echo "[Test Workflow] Compilation successful, proceeding with test..."
        
        # Step 4: Run the test
        if run_test; then
            echo "[Test Workflow] ✅ Test workflow completed successfully!"
        else
            echo "[Test Workflow] ❌ Test execution failed"
            return 1
        fi
    else
        echo "[Test Workflow] ❌ Compilation monitoring failed"
        return 1
    fi
    
    echo "=================================="
    echo "[Test Workflow] Workflow complete"
    echo "=================================="
}

# If script is run directly, execute the workflow
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_test_workflow
fi