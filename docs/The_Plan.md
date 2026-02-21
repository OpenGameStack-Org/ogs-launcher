# OGS Launcher: Minimum Viable Product & Development Plan

## Vision Alignment
This plan realizes the core vision from `docs/Design_Doc.md`: **"Sovereignty Over Subscription."** The MoSCoW method ensures we deliver the critical path to air-gap functionality and manifest-driven toolchain management without overscoping.

---

## MVP Definition: The "I/ITSEC Showcase" Build
**Target Date:** November 1, 2026 (Ready for Conference)
**Target Platform:** Windows 10/11 (x64)
**Distribution Model:** "Hub" installer (for devs) to "Sealed" artifact (for delivery)

### Primary Goals (Phase 1.5: Showcase Readiness)
1.  **Central Library Manager (Mode A)** — Launcher manages a shared pool of tools in `%LOCALAPPDATA%` to save disk space.
2.  **Project "Hydration"** — Opening a project automatically links it to the correct version in the Library (or triggers a download).
3.  **The "Seal" Protocol (Mode B)** — A working button that physically copies tools from the Library into the project and zips it up.
4.  **Offline Demo Bundle** — A pre-sealed project on a USB stick to guarantee a working demo regardless of conference Wi-Fi.

### Success Criteria
*   User runs `OGS_Setup.exe` to install the Launcher.
*   Launcher detects missing tools in `stack.json` and downloads them to `%LOCALAPPDATA%/OGS/Library/`.
*   User can have 3 projects using "Godot 4.3" while only having one copy of Godot on disk.
*   User clicks **"Seal for Delivery,"** and the Launcher produces a standalone `.zip` file containing the project AND the embedded tools.
*   That `.zip` file can be moved to a disconnected PC and run immediately.

### Demo Walkthrough (MVP Completion Gate)
The MVP is not complete until this full sequence works end to end:
1.  On a connected laptop, download and install the Launcher.
2.  Import an existing Godot project and generate `stack.json` (convert to OGS project).
3.  Use the Launcher to hydrate tools into the Central Library.
4.  Click **"Seal for Delivery"** to export a sealed `.zip` with embedded tools and Launcher.
5.  Transfer the `.zip` to an air-gapped PC, unzip, and run the Launcher from inside the sealed folder.
6.  Launch Godot (and the sample project) successfully with no network access.

---

## Phases & Progress

### Phase 1: Foundation (Internal Logic)
**Status:** 100% Complete ✅
*   (See previous logs for Manifest, Config, and Offline Enforcement completion)

---

### Phase 1.5: The Showcase MVP (Windows)
**Status:** **100% Complete** ✅
*Focus: The "Hub" Logic, Library Management, and The Seal.*

#### 📋 Critical Tasks (Must-Have for Showcase)
*   [x] **Central Library Manager (The Hub)** — 100% Complete ✅
    *   *Pathing:* Logic to manage tools in `%LOCALAPPDATA%/OGS/Library/[Tool]/[Version]/`.
    *   *Tool Discovery:* PathResolver queries available tools and versions.
    *   *Library Validation:* LibraryManager validates tools exist and retrieves metadata.
    *   *Extraction:* ToolExtractor unzips archives into library structure (Phase 2: actual unzipping).
    *   *Tests:* Unit tests validating all library operations.
*   [x] **Project Manager & Environment Validation** — 100% Complete ✅
    *   *Discovery:* ProjectsController loads and validates `stack.json`.
    *   *Validation:* ProjectEnvironmentValidator checks tools against library.
    *   *UI Integration:* Environment incomplete → shows "Repair Environment" button.
    *   *Repair Workflow:* LibraryHydrator orchestrates batch downloads (Phase 2: actual HTTP).
    *   *Tests:* Unit + scene tests covering validation and repair flow.
*   [x] **The "Seal for Delivery" Utility (Export)** — 100% Complete ✅
    *   *ProjectSealer Class:* `seal_project(project_path)` implements full workflow.
    *   *Validation:* Validates manifest and checks tool availability.
    *   *Copy Logic:* Recursively copies tool binaries from library → `./tools/`.
    *   *Config Creation:* Writes `ogs_config.json` with `force_offline=true`.
    *   *Archive Packaging:* Creates a real `.zip` artifact using Godot `ZIPPacker`.
    *   *Packaging Logs:* Logs packaging start, file count, and completion/failure events.
    *   *Tests:* Unit tests covering validation, copying, archive contents, and logging.
*   [x] **UI Integration: "Seal for Delivery" Button** — 100% Complete ✅
    *   *Scene Changes:* Added "Seal for Delivery" button to Projects page + SealDialog.
    *   *Wiring:* Connected button to ProjectSealer call in main.gd.
    *   *Result Display:* Shows seal status, zip path, size, and tools copied in dialog.
    *   *Open Folder:* "Open Sealed Folder" button to navigate to result on success.
    *   *Error Handling:* Clear error messages if project not loaded or seal fails.
*   [x] **Controller Refactoring** — 100% Complete ✅
    *   *LayoutController:* Extracted page navigation logic from main.gd (85 lines).
    *   *SealController:* Extracted seal dialog management from main.gd (120 lines).
    *   *main.gd:* Reduced from 220 → 197 lines (pure orchestration).
    *   *Code Quality:* Fixed all GDScript language server warnings (shadowed globals, unused params, static calls).
    *   *Tests:* Comprehensive coverage with zero warnings.
*   [x] **Mirror Infrastructure (Client)** — 100% Complete ✅
    *   *MirrorRepository:* Loads and validates repository.json manifests
    *   *MirrorPathResolver:* Safe path resolution with security checks
    *   *MirrorHydrator:* Offline tool installation from local archives
    *   *Settings UI:* Mirror root configuration with real-time status indicator
    *   *Onboarding Wizard:* First-run default stack bootstrap
    *   *Tests:* Comprehensive test coverage for all mirror functionality
    *   *Remote Repo Support:* Optional GitHub Releases repository.json support
    *   *Note:* Server infrastructure scale-out is post-MVP backlog
*   [x] **Onboarding Wizard** — 100% Complete ✅
    *   *First Run Detection:* Checks if wizard has been completed and library is empty
    *   *UI Dialog:* Welcoming screen with default stack information (Godot 4.3 + Blender 4.5.7)
    *   *Default Stack Bootstrap:* Creates library directory structure for default tools
    *   *Skip Option:* Users can skip wizard and configure manually
    *   *Completion Flag:* Persists to disk so wizard only shows once
*   [x] **Mirror Root Settings** — 100% Complete ✅
    *   *Settings Page UI:* Mirror root configuration field with Browse and Reset buttons
    *   *Status Indicator:* Real-time badge showing mirror configuration status (gray/green/yellow/red)
    *   *Persistence:* Mirror settings saved to `ogs_launcher_settings.json` and restored on startup
    *   *Dynamic Updates:* Mirror root changes immediately affect repair workflow
    *   *Remote Repo URL:* Optional remote repository.json configuration
*   [x] **Manual Testing Guide** — 100% Complete ✅
    *   *7 Test Scenarios:* Load sample projects, verify UI state, test seal button, configure mirror, test repair, verify status updates, remote repo config
    *   *Mirror Workflow Tests:* Settings configuration, repair with mirror, status badge updates
    *   *Prerequisites & Setup:* Clear instructions for test environment setup
    *   *Results Tracking Table:* Template for recording test outcomes

---

### Phase 2: Offline Mirror Infrastructure
**Status:** 100% Complete ✅ (Mirror Client + Initial Server Done)
*   [x] **Mirror Client Implementation** — 100% Complete ✅
    *   *MirrorRepository:* Loads and validates repository.json manifests
    *   *MirrorPathResolver:* Safe path resolution for Windows/Unix with security checks
    *   *MirrorHydrator:* Offline tool installation from local archives
    *   *ToolExtractor:* Real ZIP extraction with common-root stripping and path safety
    *   *LibraryHydrationController Integration:* Wired mirror hydration into repair workflow
    *   *Tests:* Comprehensive test coverage (schema validation, path safety, hydration, UI integration)
*   [x] **Mirror Server Infrastructure (Initial)** — GitHub Releases (v1.0)
    *   *Hosting:* GitHub Releases for "White Box" binaries
    *   *Master Manifest:* repository.json for standard frozen stack
    *   *Repo:* OpenGameStack-Org/ogs-frozen-stacks
*   [x] **Hash Verification** — 100% Complete ✅
    *   *Manifest Enforcement:* `sha256` is required for each tool entry in `repository.json`
    *   *Hydration Validation:* Local and remote mirror hydration verify archive SHA-256 before extraction
    *   *Failure Handling:* Hash mismatch blocks installation with explicit status/logging
*   [x] **Allowlist Policy** — 100% Complete ✅
    *   *Config Support:* `ogs_config.json` accepts `allowed_hosts` and `allowed_ports`
    *   *Enforcement Wiring:* `OfflineEnforcer` applies config allowlists to `SocketBlocker`
    *   *Secure Defaults:* Empty allowlist falls back to localhost-only policy

---

### Phase 3: Hardening (Future / Post-Conference)
**Status:** Post-MVP
*   [ ] **Git LFS Integration** — (Optional) Advanced workflow for Git-based teams.
*   [ ] **Godot Hardened Build** (Source Stripping).
*   [ ] **RMF Evidence Generation**.

---

## Progress Tracking
*   **Foundation:** Completed Feb 15.
*   **Showcase MVP:** Central Library, Hydration, and Seal for Delivery complete (Feb 18).
*   **Test Suite:** Comprehensive coverage (~4.0-4.3 sec execution), all suites documented including startup verification tests.
*   **Refactoring:** Controller pattern established (Projects, Hydration, Layout, Seal). Clean separation of concerns across codebase.
*   **Manual Testing:** Split into two tiers: Editor-mode (8 tests for rapid iteration) and Installed-Build (7 tests for real-world validation). See [MANUAL_TESTING.md](MANUAL_TESTING.md).

## Summary: Phase 1.5 + Phase 2 Complete

**Mirror Infrastructure (Phase 2) Completed Feb 20, 2026:**
- Mirror client implementation (MirrorRepository, MirrorPathResolver, MirrorHydrator)
- Settings UI for mirror root configuration with real-time status indicator
- Remote repository.json support (GitHub Releases)
- Onboarding wizard for first-run default stack bootstrap
- Allowlist policy (config-driven socket filtering for network security)
- Comprehensive test coverage (205 unit + scene tests, ~3.4 sec execution time)
- Full offline-only (air-gap safe) architecture

**Manual Testing Framework (Phase 2+, Feb 21, 2026):**
- Editor-mode testing guide: 8 tests for UI/logic validation in development
- Installed-build testing guide: 7 tests for packaging/portability in production
- Progressive disclosure: report findings after each test for iterative fixes

**Next: Mirror Server Scale-Out (Post-MVP)**
- S3/GitHub Releases for standard frozen stack binaries
- Master repository.json for Launcher to query
 - Scale-out hosting and access controls

**Post-Showcase: Phase 3 Hardening**
- Godot hardened build with source stripping
- RMF evidence generation for defense simulation compliance
