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

⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄VIBE-UNITY⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄

# Vibe Unity Integration Guide (Auto-generated - v1.4.0)

## Quick Reference for Claude-Code

### Scene State System (Primary Integration Point)
- **Scene Files**: `.state.json` alongside Unity scenes in `Assets/Scenes/`
- **Coverage Reports**: `.vibe-commands/coverage-analysis/` - shows what components are supported
- **Auto-generation**: State files created automatically on scene save and batch processing

### Essential Commands for Claude-Code
```bash
# Compilation validation (for claude-code script changes)
./claude-compile-check.sh                # Check compilation, return errors if found
./claude-compile-check.sh --include-warnings  # Include warning details

# Manual testing workflow (after compilation passes)
Tools > Vibe Unity > Force Recompile    # Ensure code changes compiled
Tools > Vibe Unity > Run Test File       # Process test-scene-creation.json
Tools > Vibe Unity > Scene State > Export Current Scene
```

### Batch Processing (JSON-Driven Scene Creation)
- **Drop JSON files** in `.vibe-commands/` for automatic processing
- **Test file**: `.vibe-commands/test-scene-creation.json`
- **Supported actions**: create-scene, add-canvas, add-button, add-text, add-scrollview, add-cube, etc.

### CRITICAL: Scene Creation Verification for Claude-Code
- **ALWAYS check log files** after creating a scene to verify success
- **Log location**: `.vibe-commands/logs/` directory
- **If scene creation fails**: STOP immediately and report the issue
- **Look for**: "Scene created successfully" or error messages in logs
- **Common issues**: Missing components, unsupported features, JSON syntax errors

### Current Component Support (v1.4.0)
- ✅ **UI**: Canvas, Button, Text, Image, ScrollView, TextMeshPro
- ✅ **3D**: Cube, Sphere, Plane, Cylinder, Capsule, Camera, Light
- ⚠️ **Partial**: Rigidbody, Colliders
- ❌ **Missing**: ParticleSystem, custom scripts, animations

### Compilation Validation for Claude-Code
- **Script**: `./claude-compile-check.sh` (auto-installed with package)
- **Purpose**: Validate Unity script changes without running tests
- **Output**: Structured error/warning reports with file:line locations
- **Exit Codes**: 0=success, 1=errors, 2=timeout, 3=script error
- **Usage**: Run after making C# changes to verify compilation

### Development Workflow Status
- **File Watcher**: ✅ ENABLED (automatic JSON processing)
- **HTTP Server**: DISABLED
- **CLI Commands**: DISABLED
- **Manual Testing**: ✅ ACTIVE (Use Unity menu items)
- **Claude Compile Check**: ✅ INSTALLED (automatic deployment)

## Vibe-Unity Claude Instructions
* Whenever you create or modify a script, use the vibe-unity .sh tools to compile.
* Whenever you have Unity compile, check the compilation logs for errors and warnings. Errors need to be fixed by you, and warnings should be mentioned during summarization after work is completed.
* Whenever you use vibe-unity to create or modify a scene, verify it was created properly by referring to the logs. Any parts of a scene that could not be created with Vibe-Unity should be mentioned during summarization after work is completed.
* Do NOT write to or create .meta files unless explicitly told to.
* Whenever you are tasked with something that will have you creating scenes using Vibe-Unity, immediately ask if you should "pause and ask to continue", stop what you are doing, or continue when you encounter issues creating those scenes.

## For Detailed Usage
- **Full Documentation**: [Package README](./Packages/com.ricoder.vibe-unity/README.md)
- **JSON Schema Examples**: [Package Test Files](./Packages/com.ricoder.vibe-unity/.vibe-commands/)
- **Coverage Analysis**: Check latest report in `.vibe-commands/coverage-analysis/`

^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^VIBE-UNITY^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


