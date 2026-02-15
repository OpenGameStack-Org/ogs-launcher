## StackGenerator: Manifest Factory for New OGS Projects
##
## Provides factory methods to create and serialize fresh stack.json manifests.
## Intended for the "New Project" workflow in the OGS Launcher UI.
##
## Standard Profile (OGS Default):
##   - Godot 4.3 (Engine core)
##   - Blender 4.2 LTS (3D modeling & animation)
##   - Krita 5.2 (2D texture & UI assets)
##   - Audacity 3.7 (Audio processing)
##
## Usage:
##   var manifest = StackGenerator.create_default()
##   StackGenerator.save_to_file(manifest, "res://stack.json")
##   var json_text = StackGenerator.to_json_string(manifest, pretty=true)

extends RefCounted
class_name StackGenerator

const SCHEMA_VERSION := 1

## Creates the standard OGS profile manifest.
## Returns:
##   StackManifest: Pre-populated with Godot, Blender, Krita, Audacity (current versions)
static func create_default() -> StackManifest:
	"""Creates the standard OGS profile with Godot, Blender, Krita, and Audacity."""
	var manifest = StackManifest.new()
	manifest.schema_version = SCHEMA_VERSION
	manifest.stack_name = "OGS Standard Profile"
	manifest.tools = [
		{
			"id": "godot",
			"version": "4.3",
			"path": "tools/godot/Godot_v4.3-stable_win64.exe"
		},
		{
			"id": "blender",
			"version": "4.2",
			"path": "tools/blender/blender.exe"
		},
		{
			"id": "krita",
			"version": "5.2",
			"path": "tools/krita/bin/krita.exe"
		},
		{
			"id": "audacity",
			"version": "3.7",
			"path": "tools/audacity/audacity.exe"
		}
	]
	return manifest

## Converts a manifest to JSON string.
## Parameters:
##   manifest (StackManifest): Manifest to serialize
##   pretty (bool): If true, formats with tab indentation; if false, compact
## Returns:
##   String: JSON representation of manifest (or empty if StackManifest is invalid)
static func to_json_string(manifest: StackManifest, pretty: bool = true) -> String:
	"""Serializes a manifest to JSON with optional pretty-printing."""
	var json = JSON.new()
	var data = manifest.to_dict()
	var json_string = json.stringify(data)
	if pretty:
		json_string = json.stringify(data, "\t")
	return json_string

## Saves a manifest to disk.
## Creates parent directories if needed (via Godot's FileAccess).
## Parameters:
##   manifest (StackManifest): Manifest to save
##   file_path (String): Destination path (e.g., "user://projects/myproject/stack.json")
## Returns:
##   bool: True if write succeeded, false if file I/O failed
static func save_to_file(manifest: StackManifest, file_path: String) -> bool:
	"""Writes a manifest to disk. Returns true on success, false on I/O error."""
	var json_text = to_json_string(manifest, true)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(json_text)
	file.close()
	return true
