# Security Considerations

This document lists recurring security pitfalls and checks for contributors. Use it as a checklist when changing launcher behavior, manifest handling, or any network-related features.

## Trust Boundaries

- Treat `stack.json` and `ogs_config.json` as untrusted input.
- Do not execute binaries from untrusted or unexpected locations.
- Avoid writing project paths or sensitive data to shared user storage without explicit need.

## Manifest and Tool Execution

- Enforce project-relative tool paths by default.
- Normalize resolved paths and verify they remain under the project root.
- Require SHA-256 verification when checksums are present.
- Reject unknown tools unless explicitly approved by the user.

## Network Access

- All launcher network access must go through SocketBlocker.
- Default to offline-safe behavior; require explicit enablement for network access.
- Use allowlists for hostnames and ports; log outbound attempts for auditability.

## Offline Enforcement Scope

- Offline enforcement targets launcher/editor tooling only.
- Do not modify project runtime networking; exported applications may require internal network access.

## Tool Config Injection

- Keep overrides tool-scoped and reversible.
- Avoid modifying project assets or runtime configuration.
- Prefer best-effort overrides and document any limitations.

## Data Handling

- Minimize storage of local paths in shared locations; prefer hashed project identifiers.
- Avoid storing credentials; never write secrets to disk.

## Testing Expectations

- Add unit tests for validation, path handling, and offline guards.
- Add scene tests for UI gating of network features.
