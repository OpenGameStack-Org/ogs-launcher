### OGS Launcher: Minimum Viable Product & Development Plan
#### Vision Alignment
This plan realizes the core vision from `docs/Design_Doc.md`: **"Sovereignty Over Subscription."** The MoSCoW method ensures we deliver the critical path to air-gap functionality and manifest-driven toolchain management without overscoping.

---

#### MVP Definition: The Showcase Build
**Target Date:** November 1, 2026 (Ready for Conference)
**Target Platform:** Windows 10/11 (x64)
**Distribution Goal:** Primary portable ZIP; optional installer if time permits

##### Primary Goals (Phase 1.5: Showcase Readiness)
1.  **One-Click Provisioning (Mode A)** — User downloads Launcher; Launcher downloads Godot/Blender/Krita/Audacity.
2.  **Portable Download** — A ZIP bundle that runs from a single folder with no registry/AppData dependency.
3.  **The "Hello World" Project** — A default project template so users can immediately launch a tool.
4.  **Offline Demo Bundle** — Pre-hydrated tools + sample project for conference floors with poor connectivity.

##### Success Criteria
*   User navigates to `OpenGameStack.org` and downloads the portable ZIP.
*   On first run, Launcher opens in **Mode A (Provisioning)** with clear offline warning if no network.
*   Launcher downloads the "Standard OGS Profile" (Godot 4.3, Blender 4.2, Krita 5.x, Audacity 3.x) and verifies hashes.
*   User can click "Launch Blender," and it opens the project file without manual configuration.
*   Offline demo bundle can launch tools without any network access.

---

#### Phases & Progress

##### Phase 1: Foundation (Internal Logic)
**Status:** 100% Complete ✅
*   (See previous logs for Manifest, Config, and Offline Enforcement completion)

---

##### Phase 1.5: The Showcase MVP (Windows)
**Status:** **Active / In Progress**
*Focus: Distribution, UI, and Network Provisioning.*

###### 📋 Critical Tasks (Must-Have for Showcase)
*   [ ] **Tool Download Manager (Mode A)**
    *   *Logic:* Implement `HTTP Request` downloads with progress bars.
    *   *Unpacking:* Integrated ZIP extraction for portable tools.
    *   *Pathing:* Install tools to a relative `./tools/` folder inside the portable bundle.
    *   *Guardrails:* Hard-disable all network paths when `offline_mode=true`.
*   [ ] **The "Standard Profile" Mirror**
    *   *Infrastructure:* Set up an S3 bucket or GitHub Release to host the specific "frozen" binaries for Godot, Blender, Krita, and Audacity.
    *   *Manifest:* Create a master `repository.json` that the launcher checks to find download URLs.
    *   *Licensing:* Verify redistribution terms and include attribution licenses in the bundle.
*   [ ] **Onboarding Wizard**
    *   *UI:* "Welcome to OGS. Would you like to download the Standard Development Stack?"
    *   *Action:* Triggers the batch download of the 4 core tools.
*   [ ] **Hash Verification (Mode A)**
    *   *Security:* Validate downloaded tools against SHA-256 checksums before use.
*   [ ] **Minimal "Seal for Delivery" (Mode B Demo)**
    *   *Flow:* Button to copy tools into `./tools/`, write `ogs_config.json` with `force_offline=true`, and scrub caches.
    *   *Goal:* Provide a concrete offline handoff narrative for the conference demo.
*   [ ] **Windows Packaging (Optional)**
    *   *Export:* Export Godot project as a Windows Executable.
    *   *Installer:* Create an InnoSetup (or similar) script to package the Launcher `.exe` and a default `stack.json`.
    *   *Signing:* (Optional) Code sign the installer to reduce SmartScreen warnings.

---

##### Phase 2: Integration & Sovereignty (Backlog)
**Status:** Queued
*   [ ] **"Seal for Delivery" Utility (Full)** — Full workflow for Mode A to Mode B (Air-Gap).
*   [ ] **Allowlist Policy** — Config-driven firewall rules.

---

##### Phase 3: Hardening (Future / Post-Conference)
**Status:** Post-MVP
*   [ ] **Godot Hardened Build** (Source Stripping).
*   [ ] **RMF Evidence Generation**.

---

#### Progress Tracking
*   **Foundation:** Completed Feb 15.
*   **Showcase MVP:** Started March 1. Target completion Oct 15.