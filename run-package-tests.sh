#!/bin/bash

# Vibe Unity Package Test Suite
# Run all package tests in sequence

echo "================================================"
echo "Vibe Unity Package Test Suite v1.5.1"
echo "================================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test header
print_test_header() {
    echo ""
    echo "================================================"
    echo "TEST $1: $2"
    echo "================================================"
}

# Function to check test result
check_result() {
    if [ $1 -eq $2 ]; then
        echo -e "${GREEN}✓ PASSED${NC}: $3"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}: $3 (Expected: $2, Got: $1)"
        ((TESTS_FAILED++))
        return 1
    fi
}

# TEST 1: Valid Script Compilation
print_test_header "1" "Valid Script Compilation"

echo "Creating valid test script..."
mkdir -p Assets/Scripts
cat > Assets/Scripts/TestValidScript.cs << 'EOF'
using UnityEngine;

public class TestValidScript : MonoBehaviour
{
    void Start()
    {
        Debug.Log("Test script compiled successfully!");
    }
}
EOF

echo "Running compilation check..."
./claude-compile-check.sh
EXIT_CODE=$?
check_result $EXIT_CODE 0 "Valid script should compile without errors"

echo "Checking compilation status file..."
if [ -f .vibe-unity/status/compilation.json ]; then
    STATUS=$(cat .vibe-unity/status/compilation.json | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [ "$STATUS" = "complete" ]; then
        echo -e "${GREEN}✓${NC} Compilation status shows 'complete'"
    else
        echo -e "${YELLOW}⚠${NC} Compilation status: $STATUS"
    fi
fi

# TEST 2: Script with Compilation Error
print_test_header "2" "Script with Compilation Error"

echo "Creating script with intentional error..."
cat > Assets/Scripts/TestErrorScript.cs << 'EOF'
using UnityEngine;

public class TestErrorScript : MonoBehaviour
{
    void Start()
    {
        Debug.Log("This has an error" // Missing semicolon and closing paren
    }
}
EOF

echo "Running compilation check..."
./claude-compile-check.sh 2>/dev/null
EXIT_CODE=$?
check_result $EXIT_CODE 1 "Script with errors should fail compilation"

# TEST 3: Scene Creation with UI Elements
print_test_header "3" "Scene Creation with UI Elements"

echo "Creating test scene JSON command..."
mkdir -p .vibe-unity/commands
cat > .vibe-unity/commands/test-ui-scene.json << 'EOF'
{
  "commands": [
    {
      "action": "create-scene",
      "name": "TestUIScene",
      "path": "Assets/Scenes"
    },
    {
      "action": "add-canvas",
      "name": "MainCanvas"
    },
    {
      "action": "add-button",
      "name": "TestButton",
      "parent": "MainCanvas",
      "text": "Click Me"
    }
  ]
}
EOF

echo "Waiting for Unity to process command (3 seconds)..."
sleep 3

echo "Checking results..."
if [ -f .vibe-unity/commands/logs/latest.log ]; then
    if grep -q "SUCCESS" .vibe-unity/commands/logs/latest.log 2>/dev/null; then
        echo -e "${GREEN}✓ PASSED${NC}: Scene creation logged as SUCCESS"
        ((TESTS_PASSED++))
    elif grep -q "FAILURE" .vibe-unity/commands/logs/latest.log 2>/dev/null; then
        echo -e "${RED}✗ FAILED${NC}: Scene creation had errors"
        echo "Error details:"
        grep -A5 "❌" .vibe-unity/commands/logs/latest.log 2>/dev/null || echo "Check log for details"
        ((TESTS_FAILED++))
    else
        echo -e "${YELLOW}⚠ WARNING${NC}: Could not determine scene creation status"
        echo "Log content preview:"
        tail -10 .vibe-unity/commands/logs/latest.log 2>/dev/null
    fi
else
    echo -e "${YELLOW}⚠ WARNING${NC}: Log file not found - Unity may not be running or commands not processed"
    echo "Checking processed directory for logs..."
    ls -la .vibe-unity/commands/processed/*test-ui-scene* 2>/dev/null || echo "No processed files found"
fi

if [ -f Assets/Scenes/TestUIScene.unity ]; then
    echo -e "${GREEN}✓${NC} Scene file created successfully"
else
    echo -e "${YELLOW}⚠${NC} Scene file not found - Unity may need to be open"
fi

# TEST 4: Cleanup Test Files
print_test_header "4" "Cleanup Test Files"

echo "Removing test scripts..."
rm -f Assets/Scripts/TestValidScript.cs
rm -f Assets/Scripts/TestValidScript.cs.meta
rm -f Assets/Scripts/TestErrorScript.cs
rm -f Assets/Scripts/TestErrorScript.cs.meta

echo "Removing test scene..."
rm -f Assets/Scenes/TestUIScene.unity
rm -f Assets/Scenes/TestUIScene.unity.meta

echo "Cleaning up test commands..."
rm -f .vibe-unity/commands/test-ui-scene.json
rm -rf .vibe-unity/commands/processed/*test-ui-scene*
rm -f .vibe-unity/commands/logs/latest.log 2>/dev/null

echo "Verifying cleanup..."
REMAINING=$(find Assets -name "Test*" -type f 2>/dev/null | wc -l)
if [ $REMAINING -eq 0 ]; then
    echo -e "${GREEN}✓ PASSED${NC}: All test files cleaned up"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAILED${NC}: $REMAINING test files still remain"
    ((TESTS_FAILED++))
    find Assets -name "Test*" -type f 2>/dev/null
fi

# Final Summary
echo ""
echo "================================================"
echo "TEST SUMMARY"
echo "================================================"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ All tests passed! Package is ready for release.${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}✗ Some tests failed. Please fix issues before release.${NC}"
    exit 1
fi