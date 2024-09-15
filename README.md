# Godot Automation
 
Github Actions for Godot 4 CI/CD automation.

## Features

- [x] Fully automated CI/CD pipeline for C# or GDScript projects. Supported platforms: 
    - [x] Windows
    - [x] Linux
    - [x] macOS
    - [x] Web (non-c# project only)
    - [x] Android
    - [ ] iOS
- [x] Create [github releases] automatically (needs write permissions, see [Write access to repository is not granted]).


## Usage

**New Project:**

Just click on the `Use this template` or `Fork` button to create a new repository.

**Existing Project:**

Copy the `.github` folder and the `export_presets.cfg` file to your project.

<!-- 
## Advanced 

### Android Signing

To sign your Android APK, you need to add the following secrets to your repository: -->




[github releases]: https://github.com/949886/godot-automation/releases
[Write access to repository is not granted]: https://stackoverflow.com/questions/75250751/github-actions-write-access-to-repository-is-not-granted#answers-header