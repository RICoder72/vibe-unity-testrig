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

# Vibe Unity Integration Guide (Auto-generated - v1.3.0)

## Quick Reference for Claude-Code

### Scene State System (Primary Integration Point)
- **Scene Files**: `.state.json` alongside Unity scenes in `Assets/Scenes/`
- **Coverage Reports**: `.vibe-commands/coverage-analysis/` - shows what components are supported
- **Auto-generation**: State files created automatically on scene save and batch processing

### Essential Commands for Claude-Code
```bash
# Manual testing workflow (recommended)
Tools > Vibe Unity > Force Recompile    # Ensure code changes compiled
Tools > Vibe Unity > Run Test File       # Process test-scene-creation.json
Tools > Vibe Unity > Scene State > Export Current Scene
```

### Batch Processing (JSON-Driven Scene Creation)
- **Drop JSON files** in `.vibe-commands/` for automatic processing
- **Test file**: `.vibe-commands/test-scene-creation.json`
- **Supported actions**: create-scene, add-canvas, add-button, add-text, add-scrollview, add-cube, etc.

### Current Component Support (v1.3.0)
- ✅ **UI**: Canvas, Button, Text, Image, ScrollView, TextMeshPro
- ✅ **3D**: Cube, Sphere, Plane, Cylinder, Capsule, Camera, Light
- ⚠️ **Partial**: Rigidbody, Colliders
- ❌ **Missing**: ParticleSystem, custom scripts, animations

### Development Workflow Status
- **File Watcher**: ✅ ENABLED (automatic JSON processing)
- **HTTP Server**: DISABLED
- **CLI Commands**: DISABLED
- **Manual Testing**: ✅ ACTIVE (Use Unity menu items)

## For Detailed Usage
- **Full Documentation**: [Package README](./Packages/com.ricoder.vibe-unity/README.md)
- **JSON Schema Examples**: [Package Test Files](./Packages/com.ricoder.vibe-unity/.vibe-commands/)
- **Coverage Analysis**: Check latest report in `.vibe-commands/coverage-analysis/`

---
*This section is automatically maintained by Vibe Unity v1.3.0*

