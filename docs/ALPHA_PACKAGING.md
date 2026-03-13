# Alpha Packaging Guide (Windows)

This guide defines the simplest repeatable process to produce a downloadable OGS Launcher alpha package.

## Goal

Produce a single ZIP artifact containing the launcher executable and support files for alpha distribution.

## Prerequisites

- Windows 10/11 x64
- Godot 4.3 Stable executable installed at:
  - `C:\Program Files\Godot_v4.3-stable_win64\Godot_v4.3-stable_win64.exe`
- Godot 4.3 export templates installed (Editor -> Manage Export Templates)
- Existing launcher test suite passing

### Optional for Polished Windows Metadata (Deferred)

- `rcedit.exe` configured in Godot (`Editor Settings -> Export -> Windows -> rcedit`)
- If not configured, exports still succeed but may show a warning and skip EXE resource patching (icon/version metadata)

## One-Time Setup: Export Preset

Godot export requires a local `export_presets.cfg` file in the repo root.

1. Open `project.godot` in Godot 4.3.
2. Open **Project -> Export**.
3. Add preset: **Windows Desktop**.
4. Keep preset name exactly: `Windows Desktop`.
5. Choose output executable name: `OGS-Launcher.exe` (path is overridden by script).
6. Save export presets.

## Build Command

From repo root (`ogs-launcher`):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release\build_alpha_package.ps1 -Version 0.1.0-alpha
```

### Optional Flags

- Skip tests:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release\build_alpha_package.ps1 -Version 0.1.0-alpha -SkipTests
```

- Skip zip (staging only):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release\build_alpha_package.ps1 -Version 0.1.0-alpha -SkipZip
```

## Outputs

Artifacts are generated under:

- Staging folder: `artifacts/alpha/OGS-Launcher-alpha-win64-<version>/`
- ZIP package: `artifacts/alpha/OGS-Launcher-alpha-win64-<version>.zip`

Expected files include:

- `OGS-Launcher.exe`
- `OGS-Launcher.pck` (if exported as sidecar PCK by Godot preset)
- `README_ALPHA.txt`

## Release Checklist (Minimal Alpha)

1. Run package script with a new version string.
2. Smoke test launch from staging folder.
3. Upload ZIP to GitHub Release in `OpenGameStack-Org/ogs-launcher`.
4. Mark release as pre-release (alpha).
5. Use release URL as public download link when ready.
