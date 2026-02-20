# Manual Testing Guide

## Overview

This guide documents how to manually test the OGS Launcher using the sample projects. These tests verify user-facing functionality that complements the automated test suite.

## Sample Projects

Two sample projects are provided in `samples/`:

- **sample_project:** Development/linked-mode sample with placeholder tools
  - `force_offline=false` (offline mode disabled)
  - Tools located in `tools/` subdirectory
  - Demonstrates the normal development workflow

- **sample_project_sealed:** Sealed-style sample (self-contained archive reference)
  - `force_offline=true` (offline mode enforced)
  - Tools in sealed subdirectories: `tools/godot_4.3/`, `tools/blender_4.2/`
  - Demonstrates how sealed projects behave

## Running Manual Tests

### Prerequisites

- OGS Launcher running (main.tscn in Godot editor or exported binary)
- Two sample projects available in `samples/` directory
- Visual inspection of UI state

### Test 1: Load Development/Linked Sample

**Objective:** Verify that missing tools are detected and the repair workflow is available.

**Steps:**
1. On the "Projects" page, click "Browse"
2. Select `samples/sample_project` in the file picker dialog
3. Click "Select This Folder" to load the project
4. Click "Load" on the Projects page
5. Observe the tools list and button states

**Expected Results:**
- ✅ Tools list populates with "godot v4.3" and "blender v4.2"
- ✅ "Repair Environment" button appears and is **orange** (indicating action needed)
- ✅ "Seal for Delivery" button is **disabled** (grayed out with tooltip: "Repair environment first to seal project.")
- ✅ Status label shows: "Manifest loaded (X tool(s) missing - use 'Repair Environment' to download)."
- ✅ Offline status shows: "Offline: Disabled"

**Pass Criteria:**
- Repair button is orange (color override works)
- Seal button is disabled (state management works)
- Status message reflects missing tools

---

### Test 2: Load Sealed Sample

**Objective:** Verify that sealed projects display offline enforcement and expected UI state.

**Steps:**
1. On the "Projects" page, click "Browse"
2. Select `samples/sample_project_sealed` in the file picker dialog
3. Click "Select This Folder" to load the project
4. Click "Load" on the Projects page
5. Observe the tools list and button states

**Expected Results:**
- ✅ Tools list populates with "godot v4.3" and "blender v4.2"
- ✅ "Repair Environment" button appears and is **orange** (offline mode doesn't suppress missing-tool detection)
- ✅ Online-only buttons (if any) remain disabled due to `force_offline=true`
- ✅ Offline status shows: "Offline: Forced (force_offline=true)"

**Pass Criteria:**
- `force_offline=true` visually indicated in offline status label
- Sealed project tools are recognized from manifest

---

### Test 3: Verify Seal Button State

**Objective:** Confirm that the seal button correctly transitions between enabled/disabled based on environment readiness.

**Steps:**
1. Load `sample_project` (development mode) as in Test 1
2. Observe "Seal for Delivery" button is disabled
3. (If you had all tools in the global library) verify button would be enabled after repair
4. Load `sample_project_sealed` as in Test 2
5. Observe that seal button remains disabled (tools missing from global library)

**Expected Results:**
- ✅ Seal button **disabled** when environment incomplete (tools missing from library)
- ✅ Seal button would be **enabled** (re-enabled) if all tools were present in global library
- ✅ Button has tooltip: "Repair environment first to seal project." when disabled

**Pass Criteria:**
- `btn_seal_for_delivery.disabled` state synchronizes with environment readiness
- Tooltip provides user guidance

---

### Test 4: Mirror Root Configuration (Settings Page)

**Objective:** Verify that mirror root can be configured via the Settings page and persists correctly.

**Steps:**
1. Navigate to the "Settings" page via the sidebar
2. In the "Mirror Settings" section, observe the "Mirror Root:" field
3. The field should show either:
   - Empty (if using default mirror location)
   - Or a previously saved custom path
4. Click "Reset to Default" button
5. Observe the "Mirror status" label updates to: "Mirror status: Using default location" (gray text)
6. Click "Browse" button to select a custom mirror directory
7. In the file picker, select a directory (e.g., `C:\tools\` on Windows)
8. Click "Select Current Folder"
9. Observe the "Mirror Root:" field is populated with the selected path
10. Check the "Mirror status" label:
    - If directory doesn't contain `repository.json`: "Mirror status: Directory exists, but repository.json not found" (yellow)
    - If `repository.json` exists: "Mirror status: Configured and ready" (green)
11. Close and reopen the launcher to verify the setting persists

**Expected Results:**
- ✅ "Reset to Default" clears the mirror root field
- ✅ "Browse" button opens file picker for directory selection
- ✅ Selected mirror path is saved to disk (in `ogs_launcher_settings.json`)
- ✅ Status indicator changes based on repository.json presence:
  - Gray = default location
  - Green = configured with valid repository.json
  - Yellow = directory exists but no repository.json
  - Red = directory doesn't exist
- ✅ Setting persists after closing and reopening launcher

**Pass Criteria:**
- Mirror root can be set and saved
- Status label accurately reflects mirror configuration
- Setting persists across launcher sessions

**Test Setup Prerequisites:**
- For the yellow/green path: Create a test directory with or without `repository.json`
  - Example: `C:\Tools\repository.json` (see `examples/mirror_repository.json` for format)

---

### Test 5: Repair with Mirror (Offline Hydration)

**Objective:** Verify that the repair workflow uses the configured mirror to install missing tools (when mirror is available).

**Prerequisite for this test:**
- You must have set up a mirror directory (Test 4)
- The mirror must contain:
  - `repository.json` with valid tool entries
  - Actual tool archives (ZIP files) in subdirectories matching the `archive_path` entries

**Steps:**
1. Complete Test 4 to configure a mirror root with valid `repository.json`
2. Load `sample_project` from Projects page (should show missing tools)
3. Click "Repair Environment" button
4. In the "Repair Environment" dialog, observe:
   - List of missing tools (e.g., "godot v4.3", "blender v4.2")
   - Status message shows: "Ready to install X tool(s) from mirror."
5. Click "Download and Install" button
6. Monitor the status label for progress:
   - "Installing godot v4.3..."
   - "Installed godot v4.3 successfully"
7. After all tools install, button becomes available again or dialog closes

**Expected Results:**
- ✅ Mirror hydrator attempts to locate and extract tools from archives
- ✅ Status updates during installation ("Installing...", "Installed...")
- ✅ If archive exists and is valid: Tools extracted to library
- ✅ If archive missing or invalid: Error message shown in status
- ✅ After repair completes, "Seal for Delivery" button is enabled

**Pass Criteria:**
- Mirror-based repair workflow executes without crashes
- Status messages guide the user through the process
- Tools are extracted (if archives are available)

**Common Issues:**
- **"Mirror repository not found":** Ensure `repository.json` exists in the mirror root you configured
- **"Archive not found":** Verify the `archive_path` in `repository.json` matches actual ZIP file locations
- **"SHA-256 mismatch":** If you created test archives, compute real SHA-256 hashes and update `repository.json`

---

### Test 6: Mirror Status Badge Updates

**Objective:** Verify that the mirror status label dynamically updates when mirror configuration changes.

**Steps:**
1. Navigate to Settings page
2. Observe current mirror status (should be gray if default)
3. Click "Browse" and select a directory that does NOT contain `repository.json`
4. Observe status immediately changes to yellow: "Mirror status: Directory exists, but repository.json not found"
5. Using file explorer, create an empty file named `repository.json` in that directory
   - Or copy one from `examples/mirror_repository.json`
6. Return to launcher and observe status changes to green: "Mirror status: Configured and ready"
7. Delete the `repository.json` file from disk
8. Return to launcher and observe status reverts to yellow

**Expected Results:**
- ✅ Status label updates **immediately** when mirror configuration changes
- ✅ Status reflects real-time existence of `repository.json` file
- ✅ Color coding is clear: gray = default, red = missing, yellow = incomplete, green = ready

**Pass Criteria:**
- Status badge is responsive to mirror configuration changes
- Color coding matches expected states

---

## Reporting Results

When running these manual tests, record:

| Test | Pass? | Observations | Issues |
|------|-------|--------------|--------|
| Test 1: Load sample_project | ✅/❌ | Repair button orange? Seal button disabled? | Any console errors? |
| Test 2: Load sample_project_sealed | ✅/❌ | Offline indicator shows? Tools recognized? | Any unexpected states? |
| Test 3: Seal button state | ✅/❌ | Button transitions correctly? | Does tooltip appear? |
| Test 4: Mirror configuration | ✅/❌ | Can set and reset mirror root? Status updates? | Settings persist? |
| Test 5: Repair with mirror | ✅/❌ | Mirror tools install successfully? | Console errors or crashes? |
| Test 6: Mirror status badge | ✅/❌ | Status updates in real-time? | Color coding correct? |

## Console Debugging

If tests fail, check the Godot Output panel (View → Output in editor) for:

- **JSON parsing errors:** Expected during config loading tests, not a failure
- **Missing file errors:** Check that sample project paths are correct
- **Script errors:** Indicate logic bugs in main.gd or controllers

Common console output to ignore:
```
ERROR: Parse JSON failed. Error at line 0:
   at: (core/io/json.cpp:576)
```
This is expected when loading invalid JSON files as part of tests.

## When to Update This Guide

Add new test scenarios when:
- New UI features are added (e.g., new pages or controls)
- Button state logic changes
- New sample projects are created
- Expected behavior documentation changes

Update the table of results after each test run to maintain a testing history.

---

Last updated: **February 20, 2026** (Added mirror configuration and repair workflow tests)
