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

### Phase 2.5: UX Refinement - Per-Tool Download Workflow
**Status:** 🔄 In Progress (Sprint: Feb 22-28, 2026)
*Focus: Replace batch "Repair Environment" with granular per-tool discovery and download.*

#### 📋 Short-Term Tasks (Current Sprint)
Granular, actionable items for the Tools/Projects page redesign:

**Schema & Data Layer:**
*   [ ] Add `category` field to repository.json schema (values: "Engine", "2D", "3D", "Audio")
*   [ ] Update MirrorRepository.validate_data() to accept optional category field
*   [ ] Add hardcoded category fallback in launcher (godot→Engine, blender→3D, krita→2D, audacity→Audio)
*   [ ] Update MIRROR_SCHEMA.md documentation for category field
*   [ ] Add unit tests for category validation and fallback logic

**Tools Page Redesign (UI):**
*   [ ] Create new Tools page scene structure:
    *   [ ] "Installed" section with category grouping (Engine/2D/3D/Audio)
    *   [ ] "Available" section with category grouping + Download buttons
    *   [ ] Offline fallback message ("Connect online or visit GitHub to see available tools")
*   [ ] Build ToolsController class:
    *   [ ] Fetch remote repository.json on startup (with offline fallback)
    *   [ ] Cross-reference remote tools with library to determine installed vs available
    *   [ ] Categorize and sort tools by category + version
    *   [ ] Handle individual tool download button clicks
    *   [ ] Add "Refresh" button to manually re-fetch repository.json
*   [ ] Wire ToolsController to existing MirrorHydrator/RemoteMirrorHydrator for downloads

**Projects Page Updates:**
*   [ ] Add visual indicators to project tool list:
    *   [ ] ⚠️ Yellow warning triangle: tool not installed but available in repository
    *   [ ] ❌ Red X: tool not installed and not available
    *   [ ] Tooltip on hover: "Tool not installed. Click to download."
*   [ ] Implement click-through navigation: clicking tool → jump to Tools page + highlight tool
*   [ ] Remove "Repair Environment" button from Projects page
*   [ ] Remove LibraryHydrationController integration from Projects page

**Progress Dialog Modularity:**
*   [ ] Refactor progress dialog to support:
    *   [ ] Single download (current requirement)
    *   [ ] Extensible architecture for future batch/queue operations
    *   [ ] Reusable component design (can be called from Tools or Projects page)

**Testing & Documentation:**
*   [ ] Update unit tests: remove repair workflow tests, add per-tool download tests
*   [ ] Update scene tests: new Tools page structure and Projects page indicators
*   [ ] Rewrite MANUAL_TESTING.md: replace repair scenario with per-tool download workflow
*   [ ] Update Design_Doc.md: remove references to "Repair Environment" button
*   [ ] Migration note: document deprecation of batch repair in favor of per-tool downloads

---

### Phase 3: Mid-Term Enhancements (March-May 2026)
**Status:** Planned
*Focus: Multi-tool operations, advanced UI, and performance optimization.*

**Multi-Tool Operations:**
*   Multi-select downloads (select multiple tools in Available section, "Download All Selected" button)
*   "Download All for Project" button on Projects page (one-click install all missing tools)
*   Download queue management (queue multiple tools, download sequentially with unified progress)

**Advanced UI:**
*   Collapsible category/tool/version sections (avoid overwhelming UI as repository grows)
*   Version filtering (show only latest, show all, show only versions needed by projects)
*   Tool search and filtering (find tools by name, category, or version)

**Library Management:**
*   Tool uninstall capability (remove unused tools from library to reclaim disk space)
*   Library disk usage analytics (show space used per tool, total library size)
*   Cleanup recommendations (identify unused tools across all projects)

**Performance & Caching:**
*   Cache remote repository.json locally (reduce network calls, faster startup)
*   Lazy-load tool metadata (only fetch details when user expands category)
*   Background refresh (check for repository updates without blocking UI)

---

### Phase 4: Long-Term Vision (Post-Showcase/Backlog)
**Status:** Future
*Focus: Advanced workflows, compliance, and ecosystem expansion.*

*   **Git LFS Integration** — Advanced workflow for Git-based teams to version-control tool binaries
*   **Custom Repository Support** — Allow users to configure additional tool sources beyond GitHub Releases
*   **Tool Update Notifications** — Alert users when newer versions of installed tools are available
*   **Godot Hardened Build** — Source stripping and security hardening for defense simulation environments
*   **RMF Evidence Generation** — Automated compliance reporting for defense/simulation standards
*   **Multi-Platform Support** — Expand beyond Windows to Linux and macOS builds
*   **Plugin System** — Allow community-contributed tool integrations and custom workflows

---

## Progress Tracking
*   **Foundation (Phase 1):** Completed Feb 15, 2026
*   **Showcase MVP (Phase 1.5):** Central Library, Hydration, and Seal for Delivery complete Feb 18, 2026
*   **Mirror Infrastructure (Phase 2):** Mirror client + GitHub Releases complete Feb 20, 2026
*   **Path Field Refactor:** Made optional in stack.json, library-based resolution complete Feb 22, 2026
*   **Current Sprint (Phase 2.5):** UX Refinement - Per-Tool Download Workflow (Feb 22-29, 2026)
*   **Test Suite:** 207 tests passing (~3.5 sec execution), comprehensive coverage across all components
*   **Refactoring:** Controller pattern established (Projects, Hydration, Layout, Seal, Tools)
*   **Manual Testing:** Split into two tiers: Editor-mode (8 tests) and Installed-Build (7 tests). See [MANUAL_TESTING.md](MANUAL_TESTING.md).

## Summary: Phase 1.5 + Phase 2 Complete, Phase 2.5 In Progress

**Mirror Infrastructure (Phase 2) Completed Feb 20, 2026:**
- Mirror client implementation (MirrorRepository, MirrorPathResolver, MirrorHydrator)
- Settings UI for mirror root configuration with real-time status indicator
- Remote repository.json support (GitHub Releases)
- Onboarding wizard for first-run default stack bootstrap
- Allowlist policy (config-driven socket filtering for network security)
- Comprehensive test coverage (207 unit + scene tests, ~3.5 sec execution time)
- Full offline-only (air-gap safe) architecture

**Path Field Made Optional (Feb 22, 2026):**
- stack.json `path` field is now optional (library-based resolution by default)
- ToolLauncher resolves executables from central library when path omitted
- Backward compatible: existing manifests with paths still work
- Migration notes added to MANIFEST_SCHEMA.md

**Current Sprint (Phase 2.5) - Feb 22-29, 2026:**
- UX Refinement: Replacing batch "Repair Environment" with per-tool discovery and download
- Tools page split into Installed/Available sections with category grouping
- Projects page adds visual indicators (⚠️/❌) for missing tools
- Click-through navigation from project tools to Tools page
- Remote repository.json fetching on startup with offline fallback

**Next: Mid-Term Enhancements (Phase 3 - March-May 2026)**
- Multi-select downloads and download queue management
- Collapsible UI sections for scalability
- Tool uninstall and library cleanup capabilities
- Performance optimizations and caching

**Post-Showcase: Long-Term Vision (Phase 4)**
- Git LFS integration for team workflows
- Custom repository support beyond GitHub Releases
- Tool update notifications and version management
- Godot hardened build with source stripping
- RMF evidence generation for defense simulation compliance
- Multi-platform support (Linux, macOS)
