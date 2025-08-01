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

## Workflow for Package Updates

When making changes to the package in this test rig:

1. **Make and test changes** in `./Packages/com.ricoder.vibe-unity/`
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