# OGS-Launcher: Technical Design Document

## 1. Executive Summary
The **Open Game Stack (OGS) Launcher** is a standalone application designed to bridge the gap between rapid commercial development and secure government sustainment. Unlike commercial launchers (Epic, Unity Hub), OGS operates on a **"Hub & Spoke"** architecture: it serves as a **Central Library Manager** during development (saving disk space and bandwidth) but enables the creation of **"Sealed Artifacts"**—self-contained, air-gapped simulations—for delivery. Its primary mandate is to prioritize project sovereignty over ecosystem connectivity.

---

## 2. Core Philosophy: The Two States of a Simulation
To support both modern CI/CD workflows and long-term archiving, OGS defines two distinct states for a simulation project:

### 2.1 State 1: The "Linked" Project (Development)
*   **Context:** Connected Developer Workstation.
*   **Structure:** A lightweight root folder containing a `stack.json` manifest and the source assets.
*   **Binaries:** The project does *not* contain heavy tool binaries. Instead, it "links" to a **Central Tool Library** managed by the Launcher (located in `%LOCALAPPDATA%/OGS/Library`).
*   **Efficiency:** Multiple projects using "Godot 4.3" share the same single installation, mimicking the efficiency of Unity Hub or NVM.

### 2.2 State 2: The "Sealed" Artifact (Delivery)
*   **Context:** Air-Gapped / Sovereign Sustainment.
*   **Structure:** A heavy, portable directory where the specific tool binaries have been physically **embedded** into the project structure.
*   **Sovereignty:** The artifact has zero external dependencies. It can run directly from optical media or a read-only network share in 2040 without installation.

### 2.3 The Project Wrapper
Every OGS project enforces a specific directory hierarchy to ensure "Seal" compatibility:
```text
My_Simulation_Project/
├── stack.json          # The Environment Manifest (Managed by Launcher)
├── .gitignore          # Excludes /tools/ and temporary builds
├── tools/              # (Empty in State 1; Populated in State 2)
└── project_source/     # The actual Godot Project & Assets
    ├── project.godot
    └── ...
```

---

## 3. Operational Modes & User Stories

### 3.1 Mode A: Provisioning & Development (NIPR / Commercial)
*   **Target User:** DoD Contractors, Indie Developers.
*   **Context:** Unclassified environment with internet access.
*   **Workflow:**
    1.  **Hydration (Link):** When a user opens a project, the Launcher reads `stack.json`.
        *   *Check:* Is "Godot 4.3 (Hardened)" present in the Central Library?
        *   *Action:* If no, download from the OGS Mirror. If yes, launch the project using the central binary.
    2.  **Strict Pinning:** Updates are never automatic. If the user wants to upgrade to "Godot 4.4", they must explicitly click "Upgrade Project Stack" in the Launcher UI, which updates `stack.json`.
    3.  **Source Control:** The developer commits `stack.json` and `project_source/`. The `tools/` folder is ignored via `.gitignore`, keeping the repo lightweight.

### 3.2 Mode B: Sovereign Sustainment (SIPR / Air-Gapped)
*   **Target User:** Government Program Offices, Classified Labs.
*   **Context:** Secure environment receiving the "Sealed" deliverable.
*   **Workflow:**
    1.  **Reception:** The Government receives a "Sealed Artifact" (Zip or HDD).
    2.  **Verification:** The Launcher validates that the tools inside the local `./tools/` directory match the hashes in `stack.json`.
    3.  **Isolation:** The Launcher detects the `force_offline=true` flag in the project config and disables all "Check for Updates" or "Asset Library" features.

---

## 4. The Validated Toolchain (Standard Profile)
The OGS-Launcher manages a "Standard OGS Profile" of tools known to be compliant with the "Hardened" spec.

| Tool | Version (Reference) | License | Role |
| :--- | :--- | :--- | :--- |
| **Godot Engine** | 4.3 (Hardened) | MIT | Simulation Core & Runtime |
| **Blender** | 4.5.7 | GPL | 3D Modeling & Animation |
| **Krita** | 5.2.15 | GPL | 2D Texture & UI Asset Creation |
| **Audacity** | 3.7.7 | GPL | Audio Processing |

*Note: The Launcher enforces "White Box" security by only downloading these tools from the official OGS Mirror (local or remote), where they have been pre-validated and hashed.*

---

## 5. Governance & Configuration
To guarantee "Zero Connectivity," the Launcher actively manages the configuration files of child processes.

### 5.1 Global Flag: `offline_mode=true`
When this flag is active (auto-detected in Mode B):
1.  **UI Modification:** Hides "Asset Library," "Extension Store," and "Update Available" UI elements.
2.  **Socket Lock:** Network requests from the Launcher are blocked at the application logic level.

### 5.2 Tool-Specific Overrides
Upon launching a tool, the Launcher injects configuration overrides to ensure the child process respects the air-gap:
*   **Godot (`editor_settings.tres`):**
    *   `asset_library/use_threads = false`
    *   `network/debug/bandwidth_limiter = 0`
    *   Removes HTTP Proxy settings.
*   **Blender (`userpref.blend` python override):**
    *   Executes `bpy.context.preferences.system.use_online_access = False` on startup.
    *   Disables "Check for Updates" and "Extensions" repositories.

---

## 6. The "Seal for Delivery" Protocol (Export)
This is the critical utility that converts a **State 1 (Linked)** project into a **State 2 (Sealed)** artifact.

**The "Seal" Workflow:**
1.  **Inventory Scan:** The Launcher parses `stack.json` to identify all required tools.
2.  **Binary Embedding:** The Launcher physically copies the specific tool binaries from the **Central Library** into the project's local `./tools/` directory.
3.  **Config Injection (`ogs_config.json`):**
    *   Generates a local config file in the project root.
    *   Sets `"force_offline": true`.
    *   Sets `"sealed_date": "YYYY-MM-DD"`.
4.  **Sanitization:**
    *   Removes contractor-specific user preferences and temporary build caches (`.godot`).
    *   Removes `.gitignore` (or modifies it) so the tools are now seen as part of the directory.
5.  **Packaging:** Zips the entire folder structure into a timestamped artifact (e.g., `Project_Name_Sealed_20251101.zip`).

---

## 7. Source Hardening & Build Specifications
For high-security deployments, the OGS-Launcher is paired with a **"Hardened Build"** of the Godot Engine.

### 7.1 Compilation Flags (SCons)
When compiling the "Frozen Stack" version of Godot 4.3 for Sovereign Mode:
*   `module_upnp_enabled=no` (Disables Universal Plug and Play)
*   `module_webrtc_enabled=no` (Disables WebRTC)
*   `module_websocket_enabled=no` (Disables WebSocket)

### 7.2 Source Code Stripping
*   **HTTP Requests:** The `HTTPRequest` node class is disabled/removed to prevent logic-level internet access.
*   **Asset Library:** The `editor/editor_asset_installer` module is excluded to remove the internal Asset Library tab entirely.