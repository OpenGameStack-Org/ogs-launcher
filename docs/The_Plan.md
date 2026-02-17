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
**Status:** **Active / In Progress**
*Focus: The "Hub" Logic, Library Management, and The Seal.*

#### 📋 Critical Tasks (Must-Have for Showcase)
*   [ ] **Central Library Manager (The Hub)**
    *   *Pathing:* Logic to manage tools in `%LOCALAPPDATA%/OGS/Library/[Tool]/[Version]/`.
    *   *Download:* Implement `HTTP Request` to fetch tools from the OGS Mirror if missing.
    *   *Extraction:* Unpack standard `.zip` releases into the library folders.
*   [ ] **Project Manager & Strict Pinning**
    *   *Discovery:* "Import Project" button that wraps an existing Godot project with a `stack.json`.
    *   *Validation:* On project open, check `stack.json` against the Library.
    *   *UI:* If `stack.json` requests a missing tool, show "Repair Environment" (Download) button.
    *   *Pinning:* "Upgrade Project" button to manually update `stack.json` (no auto-updates).
*   [ ] **The "Seal for Delivery" Utility (Export)**
    *   *Action:* The "Make it Sovereign" button.
    *   *Copy:* Logic to physically copy the required binaries from `%LOCALAPPDATA%` -> `./tools/`.
    *   *Config:* Write `ogs_config.json` with `force_offline=true`.
    *   *Package:* Zip the result into `[Project]_Sealed_[Date].zip`.
*   [ ] **The "Standard Profile" Mirror**
    *   *Infrastructure:* Set up S3/GitHub Release hosting the "White Box" binaries.
    *   *Manifest:* Create the master `repository.json` for the Launcher to query.
*   [ ] **Onboarding Wizard**
    *   *First Run:* "Welcome to OGS. Initializing Central Library..."
    *   *Default Stack:* One-click download of Godot 4.3 + Blender 4.2.

---

### Phase 2: Integration & Sovereignty (Backlog)
**Status:** Queued
*   [ ] **Git LFS Integration** — (Optional) Advanced workflow for teams.
*   [ ] **Hash Verification** — Validate downloaded tools against SHA-256 checksums (Security).
*   [ ] **Allowlist Policy** — Config-driven firewall rules.

---

### Phase 3: Hardening (Future / Post-Conference)
**Status:** Post-MVP
*   [ ] **Godot Hardened Build** (Source Stripping).
*   [ ] **RMF Evidence Generation**.

---

## Progress Tracking
*   **Foundation:** Completed Feb 15.
*   **Showcase MVP:** Started March 1. Target completion Oct 15.