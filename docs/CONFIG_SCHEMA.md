# OGS Config Schema

## Overview

An `ogs_config.json` file controls launcher behavior, especially air-gap enforcement and offline mode. This is the user/system configuration file, separate from the project manifest (`stack.json`).

## File Location

Typically located at the project root or in a user config directory:

```
my-game/
├── stack.json          <- Project manifest (frozen stack definition)
├── ogs_config.json     <- Launcher config (air-gap flags, user preferences)
└── game/
```

Alternatively, for system-wide configuration:
```
~/.config/ogs/ogs_config.json    (Linux)
%APPDATA%\ogs\ogs_config.json    (Windows)
```

## Schema Definition

### Root Fields

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `schema_version` | Integer | 1 | No | Must be `1` if present. |
| `offline_mode` | Boolean | `false` | No | User-triggered air-gap activation. When true, disables network features. |
| `force_offline` | Boolean | `false` | No | Immutable flag set during "Seal for Delivery". When true, enforces offline mode. |

## Example

### Minimal Config (Development)
```json
{
  "schema_version": 1,
  "offline_mode": false,
  "force_offline": false
}
```

### Offline Mode (User Preference)
```json
{
  "schema_version": 1,
  "offline_mode": true,
  "force_offline": false
}
```

### Sealed for Government (Immutable)
```json
{
  "schema_version": 1,
  "offline_mode": false,
  "force_offline": true
}
```

## Validation Rules

1. **All fields are optional** — Missing config file returns defaults with no error
2. **Boolean-only for flags** — `offline_mode` and `force_offline` must be booleans if present
3. **Schema version** — Only `1` is supported currently

### Validation Error Codes

| Error Code | Meaning |
|-----------|---------|
| `config_file_unreadable` | File I/O failed (file exists but cannot be read) |
| `config_json_invalid` | JSON parsing failed |
| `config_root_not_object` | Root must be a dictionary |
| `schema_version_not_int` | schema_version is not an integer |
| `schema_version_unsupported` | schema_version is not 1 |
| `offline_mode_not_bool` | offline_mode is not a boolean |
| `force_offline_not_bool` | force_offline is not a boolean |

## Operational Semantics

### Default Behavior (No Config File)

```gdscript
var config = OgsConfig.load_from_file("res://ogs_config.json")
# Result: offline_mode=false, force_offline=false, no errors
```

### User-Triggered Air-Gap

The user enables offline mode through the launcher UI:

```json
{
  "offline_mode": true
}
```

The launcher then:
- Disables Asset Library and Extensions UI
- Blocks all external network sockets
- Injects tool configs to disable their network features

**Scope Note:** Offline enforcement targets the launcher and editor tooling only. It does not modify project runtime networking, so exported applications can still use internal network features when required.

### Sealed Project (Government Deployment)

During "Seal for Delivery," the contractor's launcher writes:

```json
{
  "force_offline": true
}
```

When the government receives the project, the launcher detects `force_offline=true` and **immediately enforces offline mode**, regardless of the physical network status.

## Best Practices

1. **Commit ogs_config.json if using force_offline** — Ensures sealed projects stay sealed across deployments
2. **Do not hardcode network URLs in tools** — Launcher overrides tool configs to enforce offline mode
3. **Test with offline mode enabled** — Verify your project works in air-gapped environments before release
4. **Document deployment mode** — Clearly indicate whether a project is development or sealed/sovereign

## Detection & Enforcement

The launcher determines operational mode by checking:

```gdscript
if config.is_offline():  # offline_mode OR force_offline
    # Enforce Sovereign Mode
    disable_network_ui()
    block_external_sockets()
    inject_tool_configs()
```

## Future Extensions (Phase 2+)

Future versions may add:
- `cache_dir` — Custom cache location for offline downloads
- `log_file` — Path to persistent logs for debugging
- `allowed_hosts` — Whitelist of allowed domains (even in offline mode)
- `tool_config_overrides` — Per-tool environment variable injection
