This Unity project is a test rig for a package I am creating for Unity.
The package is located in Packages/com.ricoder.vibe-unity.
The package is designed to allow claude-code to generate Unity Scenes and Assets via JSON.
The package makes use of a file watching system in Unity.
There is a README.md that explains what the project is about in full detail.

# Package Development Workflow

## Important: Package Repository Location
The actual vibe-unity package repository is located at: `../vibe-unity` (relative to this test rig project)
- Test rig location: `/mnt/c/repos/vibe-unity-testrig`
- Package repo location: `/mnt/c/repos/vibe-unity`

## Development Testing Workflow (IMPORTANT)

### File Watcher Status: DISABLED
The automatic file watcher has been disabled in this development environment to avoid timing issues where code changes haven't been recompiled yet.

### Manual Testing Process (Use This!)
1. **After making code changes**: Use "Tools > Vibe Unity > Force Recompile" to ensure Unity recompiles all scripts
2. **To test functionality**: Use "Tools > Vibe Unity > Run Test File" to manually process the test file
3. **To view logs**: Check Unity Console for detailed processing logs
4. **Test file location**: `.vibe-commands/test-scene-creation.json`

### Available Menu Items
- **Run Test File**: Manually processes the test JSON file
- **Force Recompile**: Forces Unity to recompile all scripts
- **Show Debug Info**: Displays current system information
- **Configuration**: Shows current development mode settings

### New Workflow for claude-code
When claude-code makes changes to the package:
1. Code changes are made to files in `./Packages/com.ricoder.vibe-unity/`
2. Claude asks user to run "Force Recompile" if needed
3. Claude asks user to run "Run Test File" to test the changes
4. User reports back the console output for verification
5. Once confirmed working, proceed with version bump and repository sync

## Workflow for Package Updates

When making changes to the package in this test rig:

1. **Make and test changes** in `./Packages/com.ricoder.vibe-unity/` (use manual testing above)
2. **Update version** in `package.json`:
   - Patch version (1.0.x): Bug fixes and minor updates
   - Minor version (1.x.0): New features, backwards compatible
   - Major version (x.0.0): Breaking changes
3. **Update CHANGELOG.md** with version notes
4. **Commit and push** changes in the test rig
5. **Copy files** to the package repository:
   ```bash
   cp -r ./Packages/com.ricoder.vibe-unity/* ../vibe-unity/
   ```
6. **Commit and push** in the package repository with the same version

## Version Management
- ALWAYS increment the version when pushing changes
- Use semantic versioning (MAJOR.MINOR.PATCH)
- Keep versions synchronized between test rig and package repo
- Document all changes in CHANGELOG.md

## Git Remotes (SSH)
Both repositories use SSH for authentication:
- Test rig: `git@github.com:RICoder72/vibe-unity-testrig.git`
- Package: `git@github.com:RICoder72/vibe-unity.git`

# Project Workflow Notes for Claude-Code

## Important Instructions
- Do NOT write to or create .meta files unless explicitly told to
- When tasked with creating scenes using Vibe-Unity, immediately ask if you should "pause and ask to continue", stop what you are doing, or continue when you encounter issues

## Commit and Push Workflow
- When doing a commit/push, ask user if they want to update the ./vibe-unity project
- If user says yes:
  - Perform a pull into the ./vibe-unity project first
  - Copy ALL project files (except .gitignore'd files) from current project to ./vibe-unity project
  - Commit changes in ./vibe-unity project
  - Push changes to ./vibe-unity project
  - Note: Must be done from the current project path, cannot cd into the target path

## Versioning Reminder
- When commit/push this project and ../vibe-unity, make sure to increment the build version (unless I specify major or minor) in the projects and docs and docupdaters.

⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄VIBE-UNITY⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄

# Vibe Unity Integration Guide (Auto-generated - v1.4.3)

## Claude-Code Automated Workflow

### Primary Development Pattern
```bash
# 1. Validate compilation after code changes
./claude-compile-check.sh
# Exit codes: 0=success, 1=errors, 2=timeout, 3=script error

# 2. Create scenes via JSON (automatic processing)
echo '{"action":"create-scene","name":"TestScene","path":"Assets/Scenes"}' > .vibe-commands/test.json

# 3. Verify results (check logs after 3 seconds)
sleep 3 && cat .vibe-commands/logs/latest.log
```

### Automated Success/Failure Detection
- ✅ **Success Indicators**: Log contains "Scene created successfully" or "STATUS: SUCCESS"
- ❌ **Failure Indicators**: Log contains "ERROR", "FAILED", or compilation errors
- 🔄 **Claude Action**: On failure, immediately report specific error and stop workflow

### File Locations for Claude-Code
- **Compilation Check**: `./claude-compile-check.sh` (auto-installed)
- **JSON Commands**: Drop files in `.vibe-commands/` directory
- **Log Verification**: Check `.vibe-commands/logs/latest.log`
- **Coverage Reports**: `.vibe-commands/coverage-analysis/`
- **Test Template**: `.vibe-commands/test-scene-creation.json`

### Current Component Support (v1.4.3)
- ✅ **UI**: Canvas, Button, Text, Image, ScrollView, TextMeshPro
- ✅ **3D**: Cube, Sphere, Plane, Cylinder, Capsule, Camera, Light
- ⚠️ **Partial**: Rigidbody, Colliders
- ❌ **Missing**: ParticleSystem, custom scripts, animations

### JSON Command Examples for Claude-Code
```json
// Basic scene creation
{"action":"create-scene","name":"MyScene","path":"Assets/Scenes"}

// Scene with UI setup
{"action":"create-scene","name":"MenuScene","path":"Assets/Scenes/UI","components":[
  {"type":"canvas","name":"MainCanvas"},
  {"type":"button","name":"PlayButton","parent":"MainCanvas","text":"Play"}
]}

// Add 3D objects
{"action":"add-cube","name":"TestCube","position":[0,1,0],"scale":[2,2,2]}
```

### Claude-Code Decision Tree
1. **After C# changes**: Run `./claude-compile-check.sh`
   - Exit code 0: Proceed with scene creation
   - Exit code 1: Fix compilation errors immediately, report to user
   - Exit code 2+: Report timeout/system issues to user

2. **For scene operations**: Use JSON commands with automatic verification
   - Success: Continue workflow
   - Failure: Report specific error from logs, ask user for guidance

3. **Error Handling**: 
   - **Compilation errors**: STOP and fix errors
   - **Scene creation failures**: STOP, report error, ask user to check Unity Console
   - **Missing components**: Note in summary, continue with supported components

### Development Workflow Status
- **File Watcher**: ✅ ENABLED (automatic JSON processing)
- **Compilation Check**: ✅ AUTOMATED (`./claude-compile-check.sh`)
- **Log Verification**: ✅ AUTOMATED (structured log parsing)
- **Error Detection**: ✅ AUTOMATED (exit codes + log analysis)

## Automated Claude Instructions
* **ALWAYS** run `./claude-compile-check.sh` after modifying C# scripts
* **ONLY proceed** if compilation check returns exit code 0
* **VERIFY scene creation** by checking `.vibe-commands/logs/latest.log` for success/error messages
* **REPORT failures immediately** with specific error details from logs
* **DO NOT** create .meta files unless explicitly requested
* **ASK USER** for guidance only when encountering system-level failures or unsupported features

## For Detailed Usage
- **Full Documentation**: [Package README](./Packages/com.ricoder.vibe-unity/README.md)
- **JSON Schema Examples**: [Package Test Files](./Packages/com.ricoder.vibe-unity/.vibe-commands/)
- **Coverage Analysis**: Check latest report in `.vibe-commands/coverage-analysis/`

^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^VIBE-UNITY^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
