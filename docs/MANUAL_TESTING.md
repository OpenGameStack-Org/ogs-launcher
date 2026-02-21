# Manual Testing Guide

## Overview

This guide documents comprehensive manual testing of the OGS Launcher across two deployment scenarios:
1. **Editor-Mode Testing** — Testing within the Godot editor (main.tscn) for rapid feedback
2. **Installed-Build Testing** — Testing an exported OGS Launcher binary to verify production packaging

These tests verify user-facing functionality that complements the automated test suite and uncover issues that only occur in real execution environments.

## Test Philosophy

- **Editor Mode:** Rapid iteration, quick hypothesis testing, component isolation
- **Installed Mode:** Real-world usage patterns, packaging validation, user experience verification
- **Progressive Disclosure:** Each test builds on previous findings; report blockers immediately before proceeding to the next test

## Sample Projects

Two sample projects are provided in `samples/` for testing:

| Sample | Purpose | Config | Structure |
|--------|---------|--------|-----------|
| **sample_project** | Development/linked-mode testing | force_offline=false | Tools expected in library (missing state) |
| **sample_project_sealed** | Sealed/air-gapped project testing | force_offline=true | Tools physically embedded in project |

Both samples have `stack.json` with Godot 4.3 and Blender 4.5.7.

---

# PART A: EDITOR-MODE TESTING

## Prerequisites (Editor Mode)

- OGS Launcher running in Godot editor (F5 or Run Scene on main.tscn)
- Two sample projects available in `samples/` directory
- Output console visible for error messages
- Fresh state: clean library directory for consistent results

### Achieving Fresh State (Before Starting Tests)

To ensure a clean slate for testing, delete all persistent launcher data:

**IMPORTANT:** Back up any existing projects, tools, or settings you want to keep before deleting data. Fresh-state cleanup is destructive and cannot be undone.

**Option A: Using PowerShell (Recommended)**
```powershell
# Remove all OGS launcher data
Remove-Item -Path "$env:LOCALAPPDATA\OGS" -Recurse -Force -ErrorAction SilentlyContinue

# Verify deletion
if (-not (Test-Path "$env:LOCALAPPDATA\OGS")) {
    Write-Host "✓ Fresh state achieved: OGS directory removed"
} else {
    Write-Host "✗ Failed to remove OGS directory"
}
```

**Option B: Using File Explorer (Manual)**
1. Open File Explorer
2. Press Ctrl+L and paste: `%LOCALAPPDATA%\OGS`
3. If the `OGS` folder exists, delete it entirely
4. Close File Explorer

**Option C: Inside Godot Editor**
1. In Godot, open the Output panel for logs
2. Use PowerShell or File Explorer to delete `%LOCALAPPDATA%\OGS`
3. Confirm the onboarding wizard appears on next launch

### Verifying Fresh State

After cleanup, verify the fresh state is achieved:

**In PowerShell:**
```powershell
# Confirm directories don't exist
$ogsPath = "$env:LOCALAPPDATA\OGS"
if (Test-Path $ogsPath) {
    Write-Host "OGS directory still exists (not clean)"
} else {
    Write-Host "✓ Clean: No OGS directory"
}
```

**In Godot Editor:**
- Press F5 to start the launcher
- Onboarding wizard **must** appear (indicates first-run detection working)
- If no wizard appears, fresh state was not achieved

**After First Launch:**
```powershell
# Check that launcher created default structure
dir "$env:LOCALAPPDATA\OGS\"
# Should show: Library, logs, ogs_launcher_settings.json, ogs_wizard_complete.txt
```

### Editor Test 1: Launcher Startup & Onboarding

**Objective:** Verify that the launcher starts without errors and displays the onboarding wizard on first run.

**Steps:**
1. Delete `%LOCALAPPDATA%\OGS` (to simulate first run)
2. Press F5 or click Run Scene on main.tscn
3. Observe the launcher window and any dialogs
4. In the onboarding wizard, click **Start**
5. Wait for the wizard to close and the main window to remain open
6. Verify `%LOCALAPPDATA%\OGS` exists and contains `Library` and `ogs_wizard_complete.txt`

**Expected Results:**
- ✅ Launcher window appears without errors
- ✅ Scene tree loads with no "Parse Error" or compilation failures
- ✅ All page buttons visible in sidebar (Projects, Engine, Tools, Settings)
- ✅ Projects page is default/active
- ✅ Onboarding wizard appears (welcome dialog with default stack info)
- ✅ Clicking **Start** completes onboarding and closes the dialog
- ✅ `%LOCALAPPDATA%\OGS\Library` exists after onboarding completes
- ✅ `%LOCALAPPDATA%\OGS\ogs_wizard_complete.txt` exists after onboarding completes
- ✅ Output console shows no SCRIPT ERROR messages

**Pass Criteria:**
- Launcher starts cleanly
- UI is responsive and no error dialogs block the main window
- Onboarding wizard appears and completes when **Start** is clicked
- OGS data folder is created with expected files

**If test fails:**
- Check Godot Output panel for parser/script errors
- Verify all required nodes exist in main.tscn
- Confirm ogs_config.json and stack.json schemas in samples are valid

---

### Editor Test 2: Projects Page — Load sample_project (Development)

**Objective:** Verify that loading a development project shows missing tools and available repair workflow.

**Steps:**
1. Close onboarding wizard (if still visible)
2. On Projects page, click "Browse" button
3. Navigate to `samples/sample_project/` and click "Select This Folder"
4. Click "Load" button
5. Observe tools list, button states, and status labels

**Expected Results:**
- ✅ Tools list populates with two entries: "godot v4.3" and "blender v4.5.7"
- ✅ "Repair Environment" button appears and is **enabled/orange** (ready for use)
- ✅ "Seal for Delivery" button appears but is **disabled** (with reason: missing tools)
- ✅ Status label shows: "Manifest loaded. 2 tool(s) missing — use 'Repair Environment' to download."
- ✅ "Offline" label shows: "Offline: Disabled" (since force_offline=false in config)
- ✅ No errors in Output console

**Pass Criteria:**
- Project loads and manifests unmarshal correctly
- Button states reflect environment readiness (repair enabled, seal disabled)
- Offline status correctly reflects config state

**If test fails:**
- Verify sample_project/stack.json is valid JSON
- Check if sample_project/ogs_config.json exists; if not, confirm defaults apply
- Look for path resolution errors in console

---

### Editor Test 3: Projects Page — Load sample_project_sealed (Sealed/Air-Gapped)

**Objective:** Verify that sealed projects display offline enforcement and expected UI state even with missing tools.

**Steps:**
1. On Projects page, click "Browse" button
2. Navigate to `samples/sample_project_sealed/` and click "Select This Folder"
3. Click "Load" button
4. Observe offline status and button states

**Expected Results:**
- ✅ Tools list populates with "godot v4.3" and "blender v4.5.7"
- ✅ "Repair Environment" button appears and is **disabled** (offline mode prevents downloads)
- ✅ "Seal for Delivery" button remains **disabled** (tools missing from library)
- ✅ Status label shows: "Manifest loaded. 2 tool(s) missing — offline mode prevents repair."
- ✅ "Offline" label shows: **"Offline: Forced (force_offline=true)"** in distinctive color (red text)
- ✅ No online-only features in UI (if any implemented)

**Pass Criteria:**
- Sealed project config properly read and enforced
- Offline status clearly indicates force_offline state
- Repair button correctly disabled due to offline + missing tools state

**If test fails:**
- Check sample_project_sealed/ogs_config.json has force_offline=true
- Verify OfflineEnforcer.apply_config() is called during project load
- Confirm offline status label is wired to display force_offline state

---

### Editor Test 4: Settings Page — Mirror Configuration

**Objective:** Verify mirror root can be configured and status indicator updates correctly.

**Steps:**
1. Click "Settings" button in sidebar to navigate to Settings page
2. In "Mirror Settings" section, observe the "Mirror Root:" field
3. Note current status in "Mirror status:" label (should say "Using default location" or show a path)
4. Click "Reset to Default" button
5. Observe status changes; field should clear or show default path

**Expected Results:**
- ✅ Settings page loads without errors
- ✅ "Mirror Root:" field is visible and editable
- ✅ "Reset to Default" button sets field to default/empty
- ✅ "Mirror status:" label updates to: **"Mirror status: Using default location"** (gray text)
- ✅ Changes persist if you close and reopen the launcher (check settings later)

**Pass Criteria:**
- Settings page UI is functional
- Mirror configuration controls respond to user input
- Status indicator reflects current mirror state

**If test fails:**
- Verify PageSettings scene exists with MirrorRootContainer nodes
- Check mirror_root_path TextEdit node is properly wired in main.gd
- Confirm _load_mirror_settings() loads defaults correctly

---

### Editor Test 5: Settings Page — Remote Repository URL Configuration

**Objective:** Verify remote repository URL can be set and status shows configuration state.

**Steps:**
1. Stay on Settings page
2. In "Remote Repo URL:" field, paste (or type a test URL):
   ```
   https://raw.githubusercontent.com/OpenGameStack-Org/ogs-frozen-stacks/main/repository.json
   ```
3. Observe the "Mirror status:" label

**Expected Results:**
- ✅ "Remote Repo URL:" field accepts text input
- ✅ "Mirror status:" label updates to show: **"Mirror status: Remote repository configured"** (blue or distinct color)
- ✅ URL persists after closing/reopening launcher

**Pass Criteria:**
- Remote repository field is wired and functional
- Status indicator correctly recognizes remote URL configuration

**If test fails:**
- Verify mirror_repo_path TextEdit exists and is wired in main.gd
- Check _load_mirror_settings() loads repository URL from disk
- Confirm _update_mirror_status() checks for remote URL presence

---

### Editor Test 6: Seal Button State Transitions

**Objective:** Verify that "Seal for Delivery" button correctly transitions between enabled/disabled based on environment readiness.

**Steps:**
1. Load sample_project (development) — should show seal button disabled
2. Observe seal button and its tooltip
3. Load sample_project_sealed — should still show seal button disabled (tools missing from library)
4. Switch back to sample_project
5. Verify seal button is still disabled (no library tools present)

**Expected Results:**
- ✅ Seal button is **disabled** when environment is incomplete (tools missing from library)
- ✅ Seal button tooltip says: **"Repair environment first to seal project."**
- ✅ Loading different projects updates button state dynamically
- ✅ Seal button would become **enabled** (green) if all tools were somehow present in library (not testable without actual library)

**Pass Criteria:**
- Seal button state properly reflects environment readiness
- Tooltip provides clear guidance to user
- State synchronizes across project switches

**If test fails:**
- Check ProjectsController._update_seal_button_state() logic
- Verify btn_seal_for_delivery.disabled is properly set
- Confirm environment_ready/incomplete signals are emitted correctly

---

### Editor Test 7: Repair Environment Dialog — UI Structure

**Objective:** Verify repair environment dialog displays correctly and allows interaction (without actually downloading).

**Steps:**
1. Load sample_project (development state)
2. Click "Repair Environment" button
3. Observe the repair dialog that opens
4. Read the status message and tools list
5. DO NOT click "Download and Install" button (skip actual download for editor testing)
6. Close the dialog by clicking the X or "Cancel"

**Expected Results:**
- ✅ Repair dialog appears without errors
- ✅ Dialog title indicates "Repair Environment"
- ✅ Tools list shows the 2 missing tools: "godot v4.3" and "blender v4.5.7"
- ✅ Status message shows: **"Ready to install 2 tool(s) from local mirror."** (or remote if configured)
  - If no local mirror: "No local mirror repository found."
  - If remote configured: "Ready to download 2 tool(s) from remote mirror."
- ✅ "Download and Install" button is visible and enabled
- ✅ Dialog closes cleanly when dismissed

**Pass Criteria:**
- Repair dialog UI is complete and responsive
- Status message correctly identifies mirror availability
- Tools list is accurate

**If test fails:**
- Check HydrationDialog scene structure
- Verify hydration_tools_list nodes exist in scene
- Confirm hydration_status_label is wired in main.gd
- Check LibraryHydrationController setup() logic

---

### Editor Test 8: Offline Mode Enforcement — Launch Tool with Offline Active

**Objective:** Verify that launching a tool when offline is prevented with clear error messaging.

**Steps:**
1. Load sample_project_sealed (which has force_offline=true)
2. Tools list shows "godot v4.3" and "blender v4.5.7"
3. Select "godot v4.3" from tools list
4. Try to click "Launch" button (or observe if it's disabled)
5. If button is enabled, click it; if disabled, note the state

**Expected Results:**
- ✅ "Launch" button is either:
  - **Disabled** when offline mode is active (preferred UX), OR
  - **Enabled** but clicking shows error dialog: "Launching tools offline is not permitted — tools not found in local library."
- ✅ No external network calls are attempted
- ✅ Output console shows no socket-related errors

**Pass Criteria:**
- Tool launch is prevented in offline mode by design
- User receives clear feedback (disabled button or error message)

**If test fails:**
- Check OfflineEnforcer.is_offline() is called before launch
- Verify ToolLauncher throws appropriate error when offline
- Confirm error dialog or button disabling is implemented

---

## Summary: Editor Testing Checklist

After completing Editor Tests 1-8, fill in this table:

| Test | Status | Notes | Blockers |
|------|--------|-------|----------|
| 1: Startup & Onboarding | ✅/⚠️/❌ | | |
| 2: Load sample_project | ✅/⚠️/❌ | | |
| 3: Load sample_project_sealed | ✅/⚠️/❌ | | |
| 4: Mirror Config UI | ✅/⚠️/❌ | | |
| 5: Remote Repo Config | ✅/⚠️/❌ | | |
| 6: Seal Button States | ✅/⚠️/❌ | | |
| 7: Repair Dialog UI | ✅/⚠️/❌ | | |
| 8: Offline Tool Launch | ✅/⚠️/❌ | | |

---

# PART B: INSTALLED-BUILD TESTING

## Prerequisites (Installed Build)

- OGS Launcher exported as a Windows binary (ogs_launcher.exe or similar)
- Export includes all necessary DLLs, assets, and scripts
- Two sample projects available in `samples/` directory (relative to launcher or absolute path)
- Fresh state: launcher run with clean %LOCALAPPDATA%/OGS directory (simulate first user)
- Administrator access NOT required (launcher is portable)

### Achieving Fresh State for Installed Tests

Before running Installed Tests, clean up any previous launcher data to simulate a first-time user:

**IMPORTANT:** Back up any existing projects, tools, or settings you want to keep before deleting data. Fresh-state cleanup is destructive and cannot be undone.

**PowerShell One-Liner:**
```powershell
Remove-Item -Path "$env:LOCALAPPDATA\OGS" -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "✓ Fresh state ready"
```

**Verification After Export:**
1. Double-click `ogs_launcher.exe` to launch the exported binary
2. The **Onboarding wizard must appear** (confirms first-run detection)
3. Check that `%LOCALAPPDATA%/OGS/` directory was created
4. Confirm `%LOCALAPPDATA%/OGS/Library/` is empty (no pre-populated tools)

If onboarding wizard does NOT appear, fresh state was not achieved. Repeat the cleanup and relaunch.

### Installed Test 1: Launcher Export & First Launch

**Objective:** Verify that the exported launcher binary starts correctly and detects first-run state.

**Steps:**
1. Build/export OGS Launcher as a standalone Windows executable
2. Place the executable and all supporting files in a clean directory
3. Ensure %LOCALAPPDATA%/OGS directory does NOT exist (simulating first user)
4. Launch the executable by double-clicking it
5. Observe window appearance and any dialogs

**Expected Results:**
- ✅ Launcher window opens without errors or crashes
- ✅ Window title bar shows "OGS Launcher" or similar
- ✅ All UI elements (sidebar buttons, page content) render correctly
- ✅ Projects page is default/active
- ✅ Onboarding wizard appears (welcome dialog)
- ✅ %LOCALAPPDATA%/OGS/Library directory is created automatically

**Pass Criteria:**
- Launcher binary is portable and runs without external dependencies
- First-run detection works (onboarding appears)
- Launcher creates required directories

**If test fails:**
- Check that all required DLLs are included in export
- Verify launcher binary is 64-bit (matches system architecture)
- Confirm %LOCALAPPDATA% path is correctly resolved on user's system

---

### Installed Test 2: Load sample_project (Development Mode)

**Objective:** Verify the same project loading behavior as Editor Test 2, but in installed context.

**Steps:**
1. Close onboarding wizard
2. Click "Browse" button
3. Navigate to `samples/sample_project` (adjust path if samples are in a different location)
4. Click "Select This Folder"
5. Click "Load" button
6. Observe state

**Expected Results:**
- ✅ Project loads without errors
- ✅ Tools list shows "godot v4.3" and "blender v4.5.7"
- ✅ "Repair Environment" button is enabled and visible
- ✅ "Seal for Delivery" button is disabled
- ✅ Status reflects missing tools: "Manifest loaded. 2 tool(s) missing..."
- ✅ Offline status shows: "Offline: Disabled"

**Pass Criteria:**
- Same results as Editor Test 2, confirming editor and installed behavior are consistent
- Reproducible across multiple launches

**If test fails:**
- Compare results to Editor Test 2
- Check samples/sample_project/ paths are correctly resolved
- Verify file I/O works in installed context

---

### Installed Test 3: Settings Persistence Across Launches

**Objective:** Verify that launcher settings (mirror root, remote repo URL) persist between sessions.

**Steps:**
1. From Installed Test 1 (fresh launcher), navigate to Settings page
2. In "Mirror Root:" field, type or browse to a custom path (e.g., `C:\MyOGSMirror\`)
3. In "Remote Repo URL:" field, paste a test URL
4. Close the launcher completely
5. Wait a few seconds
6. Relaunch the launcher (double-click executable again)
7. Navigate back to Settings page
8. Check if your custom path and URL are still there

**Expected Results:**
- ✅ Custom mirror root path is preserved in "Mirror Root:" field
- ✅ Custom remote repo URL is preserved in "Remote Repo URL:" field
- ✅ Settings file (ogs_launcher_settings.json) exists in %LOCALAPPDATA%/OGS/
- ✅ Launcher starts reliably after settings are saved

**Pass Criteria:**
- Settings persist across launcher sessions
- No data corruption or loss of settings
- Launcher remains stable with custom settings

**If test fails:**
- Check that ogs_launcher_settings.json is created in user data directory
- Verify JSON serialization/deserialization works in installed context
- Confirm write permissions to %LOCALAPPDATA%

---

### Installed Test 4: Repair Environment (No Local Mirror) — Offline Hydration

**Objective:** Verify repair workflow when no local mirror is configured but tools exist in library.

**Prerequisite:**
- Obtain tool archives (from official OGS mirror or create test archives)
- Place them in %LOCALAPPDATA%/OGS/Library/ in the correct directory structure:
  ```
  %LOCALAPPDATA%/OGS/Library/
  ├── godot/
  │   └── 4.3/
  │       └── godot_4.3.zip
  └── blender/
      └── 4.5.7/
          └── blender_4.5.7.zip
  ```
- Ensure repository.json exists at default mirror location with matching tool entries

**Steps:**
1. Load sample_project
2. Click "Repair Environment" button
3. Observe repair dialog
4. If local mirror is configured, skip to Test 5. If not, proceed:
5. Status should show: "Ready to install 2 tool(s) from local mirror." (even with default location)
6. Click "Download and Install" button
7. Watch progress as tools extract to library
8. Allow process to complete
9. When done, close repair dialog

**Expected Results:**
- ✅ Repair dialog opens and shows missing tools list
- ✅ Status identifies available migration path (local mirror or remote)
- ✅ "Download and Install" button is enabled
- ✅ Installation progress is displayed (status updates)
- ✅ Tools are extracted to %LOCALAPPDATA%/OGS/Library/ correctly
- ✅ After completion, "Seal for Delivery" button becomes **enabled**
- ✅ No unhandled exceptions or crashes during hydration

**Pass Criteria:**
- Repair workflow completes without intervention
- Tools are properly extracted and verified
- Project becomes "seal-ready" after repair

**If test fails:**
- Check that tool archives exist in expected library location
- Verify SHA-256 hashes in repository.json match actual archive files
- Confirm extraction/unzip logic works in installed context
- Check permissions for writing to %LOCALAPPDATA%

---

### Installed Test 5: Seal for Delivery — Export Project

**Objective:** Verify the "Seal for Delivery" workflow creates a valid, portable archive.

**Prerequisite:**
- Completed Installed Test 4 (tools are in library)
- sample_project loaded with "Seal for Delivery" button enabled

**Steps:**
1. Click "Seal for Delivery" button
2. Observe seal dialog that appears
3. Monitor status as sealing progresses:
   - "Validating project..."
   - "Copying tools..."
   - "Creating archive..."
   - "Seal complete!"
4. When complete, note the sealing output summary:
   - Tools copied count
   - Project size
   - Sealed archive path
5. Click "Open Sealed Folder" button to navigate to the result
6. Verify the sealed .zip file exists with a reasonable size (>100 MB likely)

**Expected Results:**
- ✅ Seal dialog progresses through stages without errors
- ✅ Final status shows: "✓ Sealed successfully!"
- ✅ Output shows tools copied (e.g., "Tools copied: 2")
- ✅ Sealed .zip file is created in a user-visible location (e.g., user's Documents or Downloads)
- ✅ Sealed archive filename includes timestamp or project name (e.g., `sample_project_sealed_20260221.zip`)
- ✅ Archive size is substantial (confirms tools are embedded)
- ✅ File explorer opens to sealed archive location when "Open Sealed Folder" clicked

**Pass Criteria:**
- Seal workflow executes completely without crashes
- Sealed archive is created and is non-empty
- User can easily locate the sealed artifact

**If test fails:**
- Check for file system errors in console
- Verify write permissions to output directory
- Confirm ZIPPacker functionality works in installed context
- Check disk space availability

---

### Installed Test 6: Sealed Archive Portability — Extract & Launch

**Objective:** Verify that a sealed archive can be extracted on a different machine/path and launcher still works.

**Prerequisite:**
- Completed Installed Test 5 (sealed archive ready)

**Steps:**
1. Extract the sealed .zip file to a temporary directory (e.g., `C:\TestSealed\sample_project_sealed\`)
2. Inside the extracted folder, locate the OGS Launcher executable (should be at root or in a launcher subfolder)
3. Alternatively, if launcher is not included, use the same launcher executable from Installed Test 1
4. Launch the launcher from (or pointing to) the sealed project directory
5. Navigate to Projects page
6. Browse to the extracted sealed project folder
7. Click "Load"
8. Observe project state

**Expected Results:**
- ✅ Sealed project loads successfully
- ✅ Tools list shows embedded tools (godot, blender)
- ✅ "Repair Environment" button is **disabled** (offline mode active, tools present)
- ✅ "Seal for Delivery" button is **disabled** (already sealed, no reason to reseal)
- ✅ Offline status shows: **"Offline: Forced (force_offline=true)"** (from sealed config)
- ✅ Tools are shown as "available in library" (found in local ./tools/ directory)
- ✅ No network requests are made (launcher respects force_offline)

**Pass Criteria:**
- Sealed archive is portable and functional across different paths
- Offline enforcement is maintained
- No assumption about external resources

**If test fails:**
- Check that tool paths in sealed archive are correctly resolved
- Verify ogs_config.json with force_offline=true was copied into sealed archive
- Confirm path resolution works with relative paths in sealed context

---

### Installed Test 7: Network Isolation Verification (Optional Advanced)

**Objective:** Verify that no external network calls are made when offline mode is active (requires network monitoring).

**Prerequisite:**
- Network monitoring tool available (e.g., Wireshark, ProcessMonitor, or router logs)
- Sealed project loaded (with force_offline=true)

**Steps:**
1. Start network monitor to capture outbound connections from launcher
2. With sealed project loaded and force_offline=true:
   - Click "Launch" to attempt launching a tool (should be prevented)
   - Try to click any online-only button (if exists)
   - Observe repair/hydration dialog (should not allow downloads)
3. Check network monitor for any external connections initiated by launcher

**Expected Results:**
- ✅ No outbound network connections are initiated by launcher.exe
- ✅ All network-dependent features are disabled or error gracefully
- ✅ No DNS lookups to external hosts

**Pass Criteria:**
- Launcher successfully enforces air-gap at network level
- Complies with sovereign/SIPR environment requirements

**If test fails:**
- Check OfflineEnforcer._set_offline() properly sets OGS_OFFLINE environment variable
- Verify SocketBlocker.open_tcp_client() denies all non-localhost connections
- Ensure no hardcoded HTTP requests are being made without offline check

---

## Summary: Installed-Build Testing Checklist

After completing Installed Tests 1-7, fill in this table:

| Test | Status | Notes | Blockers |
|------|--------|-------|----------|
| 1: Export & First Launch | ✅/⚠️/❌ | | |
| 2: Load sample_project | ✅/⚠️/❌ | | |
| 3: Settings Persistence | ✅/⚠️/❌ | | |
| 4: Repair (Local Mirror) | ✅/⚠️/❌ | | |
| 5: Seal for Delivery | ✅/⚠️/❌ | | |
| 6: Sealed Archive Portability | ✅/⚠️/❌ | | |
| 7: Network Isolation | ✅/⚠️/❌ | Optional | |

---

### Console Debugging (Both Modes)

**In Editor Mode:**
- Check Godot Output panel (View → Output in editor)
- Look for SCRIPT ERROR, Parse Error, or Compile Error messages
- Expected (ignore): "ERROR: Parse JSON failed" during validation tests

**In Installed Mode:**
- Launcher writes logs to: `%LOCALAPPDATA%/OGS/logs/ogs_launcher.log`
- Check this file for structured JSON logs after each test
- Look for error entries with "error_code" or "error_message" fields

**Common Diagnostic Checks:**
```
# Check if library directories exist:
dir %LOCALAPPDATA%\OGS\Library\

# Check if settings persisted:
type %LOCALAPPDATA%\OGS\ogs_launcher_settings.json

# Check latest logs:
type %LOCALAPPDATA%\OGS\logs\ogs_launcher.log | findstr "error\|ERROR"
```

---

## Reporting Test Results

After each editor test, provide:
1. **Test number and name**
2. **Pass/Fail/Partial** status
3. **Observations** — what actually happened
4. **Blockers** — did this prevent the next test?
5. **Console output** — any errors seen

Example:
```
**Editor Test 2: Load sample_project — PASS ✅**

Observations:
- Project loaded successfully
- Tools list shows godot and blender correctly
- Repair button orange and enabled as expected
- Seal button disabled with correct tooltip

Blockers: None
Console: No errors
```

After completing all editor tests, move to installed-build testing with same reporting format.

---

## Future Enhancement Areas (Not Tested Yet)

- Integration with Git LFS for tool distribution
- Hardened Godot build verification
- RMF evidence generation and audit logs
- Multi-project library management (when multiple projects use same tools)
- Custom tool addition (beyond standard profile)
- Tool version upgrade workflows

---

Last updated: **February 21, 2026** (Complete restructure: editor vs. installed testing, comprehensive scenarios)
