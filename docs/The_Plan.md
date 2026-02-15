# OGS Launcher: Minimum Viable Product & Development Plan

## Vision Alignment

This plan realizes the core vision from [docs/Design_Doc.md](Design_Doc.md): **"Sovereignty Over Subscription."** The MoSCoW method ensures we deliver the critical path to air-gap functionality and manifest-driven toolchain management without overscoping.

---

## MVP Definition

### Primary Goals (Phase 1: Foundation)
1. **Manifest System** ✅ — `stack.json` loader, validator, and generator (complete)
2. **Offline Mode Enforcement** ✅ — Strict air-gap with no external sockets
3. **Projects Page** ✅ — Browse and load projects with `stack.json` detection
4. **Tool Launcher** ✅ — Launch tools from frozen stack with correct environment
5. **Configuration Management** ✅ — `ogs_config.json` for offline/sovereign mode flags

### Success Criteria
- User can select a project folder and see tool status
- User can launch Godot (or Blender) from the frozen stack
- Offline mode can be enforced globally (disables UI elements, blocks sockets)
- All test suites pass (headless)
- No external network calls in air-gapped environment

---

## Phases & Progress

### Phase 1: Foundation (Complete)

**Status:** 100% complete

#### ✅ Completed Tasks

| Task | Details | Commit/PR |
|------|---------|-----------|
| Manifest System | `StackManifest` class with full validation + error codes | [scripts/manifest/stack_manifest.gd](../scripts/manifest/stack_manifest.gd) |
| Manifest Generator | Factory `StackGenerator` for new projects | [scripts/manifest/stack_generator.gd](../scripts/manifest/stack_generator.gd) |
| Config Loader | `OgsConfig` class for `ogs_config.json` (offline mode flags) | [scripts/config/ogs_config.gd](../scripts/config/ogs_config.gd) |
| Test Harness | Headless test runner + 118 unit/scene tests (all passing) | [tests/](../tests/) |
| Testing Documentation | Comprehensive testing guide with categories and best practices | [docs/TESTING.md](TESTING.md) |
| Projects Page UI | Folder selection, manifest/config loading, tool list display | [scripts/projects/projects_controller.gd](../scripts/projects/projects_controller.gd) |
| Tool Launcher | Process spawning with tool-specific arguments and environment setup | [scripts/launcher/tool_launcher.gd](../scripts/launcher/tool_launcher.gd) |
| Offline Mode Enforcement | UI disabling, socket blocking, tool config injection, and download guardrails | [scripts/network/offline_enforcer.gd](../scripts/network/offline_enforcer.gd) |
| Documentation | Comprehensive docstrings + schema guides (manifest + config) | [docs/MANIFEST_SCHEMA.md](MANIFEST_SCHEMA.md), [docs/CONFIG_SCHEMA.md](CONFIG_SCHEMA.md) |
| Project Structure | Git setup, .gitignore configured, workspace file ready | [.github/](.github/) |

**Notes:**
- Launcher-level offline enforcement, UI disabling, and download guardrails are in place. Tool config injection is implemented for Godot, Blender, Krita, and Audacity (placeholder overrides). Socket-level blocking is implemented and wired through tool downloads. Offline enforcement does not alter project runtime networking.

#### 📋 Must-Have for MVP

- [x] **Config System** — Load `ogs_config.json` (offline_mode flag, project paths)
- [x] **Projects Page** — Select folder → detect/load `stack.json` → display tool status
- [x] **Tool Launch** — Click "Launch Godot" → spawn process with correct environment
- [x] **Offline Enforcement** — When `offline_mode=true`, disable all network UI and block sockets

---

### Phase 2: Integration (Backlog)

**Status:** Not started

#### Should-Have Tasks

- [ ] **Tool Download** (Provisioning Mode) — Detect missing tools, fetch from mirrors
- [ ] **Hash Verification** (Sovereign Mode) — Validate tool binaries against SHA-256 checksums
- [ ] **Seal for Delivery** — UI workflow to freeze project + sanitize artifacts
- [ ] **Settings Page** — Toggle offline mode, manage tool versions, configure cache paths
- [ ] **Allowlist Policy** — Config-driven allowlist for outbound hosts/ports via `ogs_config.json`

#### Could-Have Tasks

- [ ] **Project Templates** — Generate new OGS projects with empty game structure
- [ ] **Editor Integration** — Godot Asset Library override, theme customization
- [ ] **Logging** — Persistent logs for troubleshooting air-gap deployments
- [ ] **CI/CD** — Automated test suite on commits, manifest validation in pipelines

---

### Phase 3: Hardening (Future)

**Status:** Post-MVP

- [ ] **Godot Hardened Build** — Compile with UPnP, WebRTC, WebSocket disabled
- [ ] **Cryptographic Validation** — GPG signing or SPIFFE for tool provenance
- [ ] **RMF Compliance** — Evidence generation for supply chain audits
- [ ] **Performance Optimization** — Reduce startup time, minimize memory footprint

---

## Dependencies & Blocking Issues

### Critical Path
```
Config Loader
    ↓
Offline Mode Enforcement
    ↓
Projects Page (depends on Config + Enforcement)
    ↓
Tool Launcher (depends on Projects Page + Config)
```

### Known Constraints
- Godot 4.3 headless mode has limitations with dynamic script loading (workaround: explicit preload paths)
- Windows/Linux path differences (mitigated by using relative paths + forward slashes)
- FileAccess limitations in air-gap (all I/O is local filesystem only)

---

## Running Tests

All changes should pass the manifest test suite before merging:

```bash
godot --headless --script res://tests/test_runner.gd
```

Expected output: `tests passed: 118, tests failed: 0`

## Definition of Done

A task is "complete" when:

1. **Code** — Changes merged to `main`
2. **Tests** — New tests added; existing tests still pass
3. **Docs** — Docstrings added; [MANIFEST_SCHEMA.md](MANIFEST_SCHEMA.md) or relevant docs updated
4. **Security** — No external dependencies; no network calls in offline mode; no credential storage
5. **Review** — At least one maintainer review on pull request

---

## Progress Tracking

Check this file regularly. Tasks will be moved between sections as work progresses. Each section shows the latest status, expected owner, and acceptance criteria.

Last updated: **February 15, 2026** (Offline Enforcement complete)
