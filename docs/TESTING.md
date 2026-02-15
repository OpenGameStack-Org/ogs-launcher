# Testing Guide

## Overview

The OGS Launcher uses a comprehensive test suite to ensure reliability and maintainability. Tests are categorized into **unit tests** (pure logic, no UI) and **scene tests** (integration tests with UI nodes).

## Running Tests

Execute the full test suite in headless mode:

```bash
godot --headless --script res://tests/test_runner.gd
```

Expected output:
```
tests passed: 87
tests failed: 0
```

**Note:** You may see `ERROR: Parse JSON failed` messages during test runs. These are expected from tests that validate invalid JSON handling.

## Test Categories

### Unit Tests (Fast, No Scene)

Unit tests validate pure logic without instantiating UI nodes. These run quickly and focus on data validation, parsing, and business logic.

**Current unit test suites:**

- **[tests/stack_manifest_tests.gd](tests/stack_manifest_tests.gd)** — Validates `stack.json` loading, schema compliance, and error codes.
  - Valid manifests pass
  - Required fields enforced (schema_version, stack_name, tools)
  - Float schema_version handling (1.0 accepted, 1.5 rejected)
  - Invalid JSON/types rejected
  - SHA-256 checksum validation
  - Tool entry validation

- **[tests/ogs_config_tests.gd](tests/ogs_config_tests.gd)** — Validates `ogs_config.json` loading and offline mode detection.
  - Valid configs load correctly
  - Missing files return defaults (no error)
  - Float schema_version handling
  - Invalid JSON rejected
  - Boolean type enforcement for offline flags

- **[tests/stack_generator_tests.gd](tests/stack_generator_tests.gd)** — Validates manifest generation and serialization.
  - Default manifest contains standard tools
  - JSON pretty-printing (newlines, tabs)
  - JSON compact mode (no whitespace)
  - save_to_file() writes and returns true

- **[tests/tool_launcher_tests.gd](tests/tool_launcher_tests.gd)** — Validates tool process spawning logic.
  - Missing/empty path fields rejected
  - Invalid project directory rejected
  - Nonexistent tool executable rejected
  - Tool-specific arguments built correctly (Godot, Blender, unknown)
  - Absolute paths used as-is (no project directory joining)
  - Relative paths joined with project directory

- **[tests/offline_enforcer_tests.gd](tests/offline_enforcer_tests.gd)** — Validates offline enforcement state and network guard behavior.
  - Null config resets enforcement
  - offline_mode and force_offline enable enforcement
  - Disabled config keeps enforcement off
  - Guard allows when online and blocks when offline

- **[tests/tool_downloader_tests.gd](tests/tool_downloader_tests.gd)** — Validates that download attempts are blocked in offline mode.
  - Offline attempts return OFFLINE_BLOCKED
  - Online attempts return NOT_IMPLEMENTED (stubbed)

### Scene Tests (Integration with UI)

Scene tests instantiate UI nodes and verify controller behaviors. These are similar to Unity's "Play Mode tests" but run headlessly in Godot.

**Current scene test suites:**

- **[tests/projects_controller_scene_tests.gd](tests/projects_controller_scene_tests.gd)** — Validates Projects page controller logic.
  - Empty path → status prompts selection
  - Missing `stack.json` → error message + cleared tools list
  - Valid sample project → tools list populated + offline label updated
  - Launch button disabled initially
  - Launch button enabled after valid project load
  - Launch with no selection → error message

- **[tests/main_scene_tests.gd](tests/main_scene_tests.gd)** — Smoke tests for the main launcher scene.
  - main.tscn loads without errors
  - All page nodes exist (Projects, Engine, Tools, Settings)
  - New Project button exists

## Test Structure

Each test suite:
1. Extends `RefCounted`
2. Has a `class_name` for registration
3. Implements `run() -> Dictionary` returning `{"passed": int, "failed": int, "failures": Array[String]}`
4. Uses `_expect(condition, message, results)` helper for assertions

### Example Unit Test

```gdscript
extends RefCounted
class_name MyFeatureTests

func run() -> Dictionary:
    var results := {"passed": 0, "failed": 0, "failures": []}
    _test_valid_input(results)
    _test_invalid_input(results)
    return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
    if condition:
        results["passed"] += 1
    else:
        results["failed"] += 1
        results["failures"].append(message)

func _test_valid_input(results: Dictionary) -> void:
    var config = MyFeature.load("valid_data")
    _expect(config.is_valid(), "valid data should pass", results)
```

### Example Scene Test

```gdscript
extends RefCounted
class_name MyControllerSceneTests

func run() -> Dictionary:
    var results := {"passed": 0, "failed": 0, "failures": []}
    _test_ui_interaction(results)
    return results

func _test_ui_interaction(results: Dictionary) -> void:
    var controller = MyController.new()
    var label = Label.new()
    controller.setup(label)
    controller.do_something()
    _expect(label.text == "Expected", "label should update", results)
    label.free()  # Clean up to avoid leaks
```

## Adding New Tests

### 1. Create Test File

Create a new test file in `tests/` with `class_name`:

```gdscript
extends RefCounted
class_name MyNewTests
```

### 2. Register in Test Runner

Add to [tests/test_runner.gd](tests/test_runner.gd):

```gdscript
var my_new_tests = load("res://tests/my_new_tests.gd")
if my_new_tests:
    test_suites.append(my_new_tests.new())
```

### 3. Run and Verify

```bash
godot --headless --script res://tests/test_runner.gd
```

## Best Practices

### General
- Write tests alongside new features (don't defer testing)
- Keep tests focused: one assertion per test method when possible
- Use descriptive test method names (`_test_empty_path_shows_error` over `_test_1`)

### Unit Tests
- Test both valid and invalid inputs
- Verify error codes/messages explicitly
- Avoid file I/O when possible (use in-memory data)

### Scene Tests
- Always free created UI nodes to avoid resource leaks
- Test user-facing behaviors, not internal implementation
- Use sample data from `samples/` when testing file loading

### Cleanup
- Free all created nodes in scene tests
- Delete temporary files created during tests
- Avoid leaving state that could affect subsequent tests

## Continuous Integration

All pull requests must pass the test suite. The CI pipeline runs:

```bash
godot --headless --script res://tests/test_runner.gd
```

Exit code 0 = all tests passed; exit code 1 = failures detected.

## Troubleshooting

### Tests Hang or Don't Complete

- Check for infinite loops in test logic
- Ensure all UI nodes are freed (resource leaks can cause hangs)
- Run with `--verbose` to see detailed output

### "Class not found" Errors

- Ensure `class_name` is declared in the source file
- Add preload statements in `test_runner.gd` if needed
- Open the project in Godot editor once to register classes

### Resource Leak Warnings

Scene tests must free all created nodes:

```gdscript
func _test_something(results: Dictionary) -> void:
    var label = Label.new()
    # ... test logic ...
    label.free()  # Critical: always free
```

## Coverage Goals

Target coverage for all new features:
- **Business logic** → 100% unit test coverage
- **UI controllers** → Scene tests for critical user flows
- **Utilities** → Unit tests for edge cases and error handling

---

Last updated: **February 15, 2026**
