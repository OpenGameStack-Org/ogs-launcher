# OGS-Launcher: Technical Design Document

## 1. Executive Summary
The **Open Game Stack (OGS) Launcher** is a standalone, portable application designed to manage "Frozen Stacks" of open-source simulation tools. Unlike commercial launchers (Epic Games Launcher, Unity Hub), OGS acts as a dual-use bridge: it serves as a **Provisioning Tool** for the open internet and a **Sovereign Environment Manager** for air-gapped defense networks. Its primary mandate is to prioritize project sovereignty over ecosystem connectivity.

## 2. Core Philosophy: The "Frozen Stack"
A "Frozen Stack" is a directory containing specific, immutable versions of tools required to build a specific project. It relies on **Relative Paths** to ensure portability across different drives, secure networks, or optical media.

### 2.1 The Manifest (`stack.json`)
Every project includes a `stack.json` file at its root, defining the exact environment required to open it. The Launcher reads this manifest to locate the correct binaries within the portable directory structure.

## **3. Operational Modes & User Stories**
The OGS-Launcher is designed to facilitate the full lifecycle of a defense program, from unclassified contractor development to classified government sustainment.

### **3.1 Mode A: Provisioning & Development (NIPR / Commercial)**
*   **Target User:** DoD Contractors, Indie Developers, Prototyping Teams.
*   **Context:** Unclassified development environment with internet access.
*   **Workflow:**
    *   **Hydration:** The contractor clones the project repository. The Launcher detects missing tools in the `tools/` directory and fetches the exact versions defined in `stack.json`.
    *   **Updates:** The contractor can update tool versions (e.g., Godot 4.3 -> 4.3.1). The Launcher updates `stack.json` to reflect the new baseline.
    *   **Commitment:** The contractor commits both the project source assets **and** the updated `stack.json` (and optionally the `tools/` binaries via Git LFS) to the Version Control System (VCS).

### **3.2 Mode B: Sovereign Sustainment (SIPR / Air-Gapped)**
*   **Target User:** Government Program Offices, Classified Labs.
*   **Context:** Secure environment receiving the contractor's deliverable.
*   **Workflow:**
    *   **Reception:** The Government receives the repository (via physical media or cross-domain solution).
    *   **Verification:** The Launcher validates that the hash of the tools in `tools/` matches the `stack.json` manifest.
    *   **Lockdown:** The Launcher detects the environment is restricted (or is manually set to `offline_mode=true`) and disables all external fetch capabilities, running purely from the committed artifacts.

## 4. The Validated Toolchain (Standard Profile)
The OGS-Launcher is optimized to manage the "Standard OGS Profile." While the launcher is agnostic, the following specific versions constitute the reference architecture for RMF compliance:

| Tool | Version (Reference) | License | Role |
| :--- | :--- | :--- | :--- |
| **Godot Engine** | 4.3 (Hardened) | MIT | Simulation Core & Runtime |
| **Blender** | 4.2 LTS | GPL | 3D Modeling & Animation |
| **Krita** | 5.x | GPL | 2D Texture & UI Asset Creation |
| **Audacity** | 3.x | GPL | Audio Processing |

## 5. Governance & Configuration
To guarantee "Zero Connectivity", the Launcher actively manages the configuration files of child processes to override default behaviors.

### 5.1 Global Flag: `offline_mode=true`
When the Launcher detects this flag in `ogs_config.json`:
1.  **UI Modification:** Hides "Asset Library," "Extension Store," and "Update Available" UI elements.
2.  **Socket Lock:** Attempts to initialize network requests return an immediate error without contacting the OS network stack.

**Scope Note:** Offline enforcement applies to the launcher and editor tooling only. It does not modify project runtime networking, so exported Godot applications can still use network features when required.

### 5.2 Tool-Specific Overrides
Upon launching a tool, the Launcher injects or validates specific configuration overrides to ensure the child process respects the air-gap:

*   **Godot (`editor_settings.tres`):**
    *   Sets `asset_library/use_threads = false`
    *   Sets `network/debug/bandwidth_limiter = 0`
    *   Disables "Editor Settings > Network > HTTP Proxy" functionality.
*   **Blender (`userpref.blend` python override):**
    *   Script execution on launch: `bpy.context.preferences.system.use_online_access = False`
    *   Disables "Check for Updates" and "Extensions" repositories.
*   **Krita/Audacity (placeholder overrides):**
    *   Writes `user://ogs_offline_overrides/<tool>.json` with a hashed `project_id` and sets `OGS_OFFLINE_TOOL_<TOOL>` environment flags
    *   Placeholder until tool-native config files are integrated

### 5.3 Logging Architecture
The launcher uses structured JSON logs written to `user://logs/ogs_launcher.log` with size-based rotation. Logs are intended for operational events (project load, tool launch, network guardrails) and must avoid sensitive data such as raw filesystem paths.

## **6. The "Seal for Delivery" Protocol**
To enable the seamless transition from Contractor (Mode A) to Government (Mode B), the Launcher includes a **"Seal Project"** utility. This feature prepares the environment for final delivery or source control archival.

1.  **Binary Freezing:**
    *   The Launcher moves all referenced tools from local caches into the project’s local `./tools/` directory.
    *   It generates a `.gitignore` exception list to ensure these binaries are tracked by the VCS (or configured for Git LFS), ensuring the "Environment is the Artifact."

2.  **Configuration Injection (`ogs_config.json`):**
    *   The Launcher generates a local configuration file intended for the repository root.
    *   **Option: "Enforce Offline":** A boolean flag (`"force_offline": true`) is written to the config. When the Government opens this project, the Launcher reads this flag and *immediately* enforces Mode B, regardless of the physical network status.

3.  **Sanitization:**
    *   Removes all contractor-specific user preferences, temporary build caches (`.godot`), and editor history, ensuring the Government receives a "clean room" version of the stack.

## 7. Source Hardening & Build Specifications
For high-security deployments, the OGS-Launcher is paired with a **"Hardened Build"** of the Godot Engine. This section specifies the build flags required to physically strip networking capabilities from the engine binary, as detailed in the project Outline.

### 7.1 Compilation Flags (SCons)
When compiling the "Frozen Stack" version of Godot 4.3 for Sovereign Mode, the following flags must be set to `no`:

```bash
# SCons Build Arguments for OGS Hardened Profile
scons platform=windows target=editor \
    module_upnp_enabled=no \       # Removes Universal Plug and Play
    module_webrtc_enabled=no \     # Removes WebRTC connectivity
    module_websocket_enabled=no \  # Removes WebSocket support
    module_enet_enabled=no \       # Removes High-level multiplayer API
    builtin_certs=no               # Removes bundled SSL certificates
```

### 7.2 Source Code Stripping
*   **HTTP Requests:** The `HTTPRequest` node class is disabled or removed from the `scene/main` directory to prevent logic-level internet access.
*   **Asset Library:** The `editor/editor_asset_installer` module is excluded from the build to remove the internal Asset Library tab entirely.