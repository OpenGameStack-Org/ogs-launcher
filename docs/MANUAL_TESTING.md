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

## Reporting Results

When running these manual tests, record:

| Test | Pass? | Observations | Issues |
|------|-------|--------------|--------|
| Test 1: Load sample_project | ✅/❌ | Repair button orange? Seal button disabled? | Any console errors? |
| Test 2: Load sample_project_sealed | ✅/❌ | Offline indicator shows? Tools recognized? | Any unexpected states? |
| Test 3: Seal button state | ✅/❌ | Button transitions correctly? | Does tooltip appear? |

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

Last updated: **February 20, 2026**
