# Mirror Repository Schema

## Overview

A local mirror is a portable, offline-only bundle of tool archives. The launcher reads a `repository.json` file from the mirror root to discover which tools and versions are available.

This schema is designed for air-gapped environments and contains only local paths. No network URLs are required.

## File Location

```
mirror_root/
├── repository.json
└── tools/
    ├── godot/4.3/godot_4.3_win64.zip
    ├── blender/4.2/blender_4.2_win64.zip
    ├── krita/5.2/krita_5.2_win64.zip
    └── audacity/3.7/audacity_3.7_win64.zip
```

## Default Mirror Root

- Windows: `%LOCALAPPDATA%/OGS/Mirror`
- Linux/macOS: `~/.config/ogs-launcher/mirror`

## Schema Definition

### Root Fields

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `schema_version` | Integer | Yes | Must be `1`. Future versions may extend this schema. |
| `mirror_name` | String | Yes | Human-readable mirror name (e.g., "OGS Standard Profile"). |
| `tools` | Array | Yes | Array of tool entries. Must contain at least one entry. |

### Tool Entry Fields

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `id` | String | Yes | Tool identifier (e.g., `"godot"`, `"blender"`). |
| `version` | String | Yes | Tool version (e.g., `"4.3"`). |
| `archive_path` | String | Yes | Relative path to the tool archive inside the mirror. |
| `sha256` | String | No | SHA-256 checksum (64 lowercase hex). Strongly recommended. |
| `size` | Integer | No | Archive size in bytes (informational). |

## Example

```json
{
  "schema_version": 1,
  "mirror_name": "OGS Standard Profile",
  "tools": [
    {
      "id": "godot",
      "version": "4.3",
      "archive_path": "tools/godot/4.3/godot_4.3_win64.zip",
      "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
      "size": 123456789
    },
    {
      "id": "blender",
      "version": "4.2",
      "archive_path": "tools/blender/4.2/blender_4.2_win64.zip",
      "sha256": "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789",
      "size": 987654321
    }
  ]
}
```

## Validation Rules

1. `schema_version` must be integer `1`.
2. `mirror_name` must be a non-empty string.
3. `tools` must be a non-empty array of objects.
4. Each tool entry must include `id`, `version`, and `archive_path`.
5. `archive_path` must be a relative path inside the mirror root (no absolute paths or `..`).
6. If `sha256` is provided, it must be 64 lowercase hex characters.
7. If `size` is provided, it must be an integer greater than `0`.

## Operational Behavior

- The launcher reads `repository.json` from the mirror root.
- Tool archives are verified by `sha256` when present.
- Archives are extracted into the central library at `%LOCALAPPDATA%/OGS/Library/` (Windows) or `~/.config/ogs-launcher/library` (Linux/macOS).
- No network connections are used during mirror hydration.

---

Last updated: February 20, 2026
