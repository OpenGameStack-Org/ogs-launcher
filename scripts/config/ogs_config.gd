## OgsConfig: Launcher Configuration Loader
##
## Manages the `ogs_config.json` configuration file that controls launcher behavior,
## especially air-gap enforcement and offline mode.
##
## Configuration controls two primary concerns:
##   1. offline_mode (user preference) — User-triggered air-gap activation
##   2. force_offline (immutable) — Set during "Seal for Delivery" for government/secure deployments
##
## When offline_mode OR force_offline is true, the launcher:
##   - Disables asset library and extension UI
##   - Blocks all external network sockets
##   - Injects tool configs to disable their network features
##
## Usage:
##   # Load from disk (or return defaults if missing)
##   var config = OgsConfig.load_from_file("res://ogs_config.json")
##   if config.is_offline():
##       print("Air-gap mode active: networking disabled")
##
##   # Build from dictionary
##   var config = OgsConfig.from_dict({\"offline_mode\": true})
##
## Schema Version:
##   Currently supports version 1. Future versions may add logging, cache paths, etc.

extends RefCounted
class_name OgsConfig

const Logger = preload("res://scripts/logging/logger.gd")

const CURRENT_SCHEMA_VERSION := 1

var schema_version := 1
var offline_mode := false
var force_offline := false
var errors: Array[String] = []

static func load_from_file(file_path: String) -> OgsConfig:
	"""Loads config from disk. Returns default config if file doesn't exist.
	Parameters:
	  file_path (String): Path to ogs_config.json
	Returns:
	  OgsConfig: Instance with values from file, or defaults if file is missing/invalid."""
	var config := OgsConfig.new()
	config._load_from_file(file_path)
	return config

static func parse_json_string(json_text: String) -> OgsConfig:
	"""Parses config JSON text.
	Parameters:
	  json_text (String): Raw JSON string
	Returns:
	  OgsConfig: Instance with values from JSON, or with validation errors."""
	var config := OgsConfig.new()
	config._load_from_json_string(json_text)
	return config

static func from_dict(data: Dictionary) -> OgsConfig:
	"""Builds config from dictionary.
	Parameters:
	  data (Dictionary): Object to load from
	Returns:
	  OgsConfig: Instance with values from dict, or with validation errors."""
	var config := OgsConfig.new()
	config._load_from_dict(data)
	return config

func is_offline() -> bool:
	"""Checks if air-gap mode is active (either user preference or forced).
	Returns:
	  bool: True if offline_mode OR force_offline is true."""
	return offline_mode or force_offline

func is_valid() -> bool:
	"""Checks if config loaded without validation errors.
	Returns:
	  bool: True if .errors is empty."""
	return errors.is_empty()

func to_dict() -> Dictionary:
	"""Converts config to dictionary for serialization.
	Returns:
	  Dictionary: {\"schema_version\": int, \"offline_mode\": bool, \"force_offline\": bool}"""
	return {
		"schema_version": schema_version,
		"offline_mode": offline_mode,
		"force_offline": force_offline
	}

static func validate_data(data: Dictionary) -> Array[String]:
	"""Validates config dictionary against schema.
	Parameters:
	  data (Dictionary): Object to validate
	Returns:
	  Array[String]: Error code list. Empty = validation passed."""
	var found_errors: Array[String] = []
	
	if data.has("schema_version"):
		var schema_value = data["schema_version"]
		if typeof(schema_value) == TYPE_INT:
			if int(schema_value) != CURRENT_SCHEMA_VERSION:
				found_errors.append("schema_version_unsupported")
		elif typeof(schema_value) == TYPE_FLOAT:
			if int(schema_value) != schema_value:
				found_errors.append("schema_version_not_int")
			elif int(schema_value) != CURRENT_SCHEMA_VERSION:
				found_errors.append("schema_version_unsupported")
		else:
			found_errors.append("schema_version_not_int")
	
	if data.has("offline_mode"):
		if typeof(data["offline_mode"]) != TYPE_BOOL:
			found_errors.append("offline_mode_not_bool")
	
	if data.has("force_offline"):
		if typeof(data["force_offline"]) != TYPE_BOOL:
			found_errors.append("force_offline_not_bool")
	
	return found_errors

func _load_from_file(file_path: String) -> void:
	"""Internal: Loads JSON from disk. Returns defaults if file is missing.
	Parameters:
	  file_path (String): Path to ogs_config.json"""
	errors.clear()
	if not FileAccess.file_exists(file_path):
		# File missing is not an error—use defaults
		Logger.debug("config_missing", {"component": "config"})
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		Logger.warn("config_read_failed", {"component": "config"})
		errors.append("config_file_unreadable")
		return
	var json_text = file.get_as_text()
	file.close()
	_load_from_json_string(json_text)

func _load_from_json_string(json_text: String) -> void:
	"""Internal: Parses JSON string.
	Parameters:
	  json_text (String): Raw JSON to parse"""
	errors.clear()
	var data = JSON.parse_string(json_text)
	if data == null:
		Logger.warn("config_parse_failed", {"component": "config"})
		errors.append("config_json_invalid")
		return
	if typeof(data) != TYPE_DICTIONARY:
		Logger.warn("config_root_invalid", {"component": "config"})
		errors.append("config_root_not_object")
		return
	_load_from_dict(data)

func _load_from_dict(data: Dictionary) -> void:
	"""Internal: Populates fields from dictionary with validation.
	Parameters:
	  data (Dictionary): Object to load from"""
	errors = validate_data(data)
	if not errors.is_empty():
		Logger.warn("config_validation_failed", {"component": "config", "error_count": errors.size()})
	
	if data.has("schema_version"):
		schema_version = int(data["schema_version"])
	
	# Use explicit bool conversion: get with defaults, then check truthiness
	var offline_value = data.get("offline_mode", false)
	offline_mode = offline_value if typeof(offline_value) == TYPE_BOOL else false
	
	var force_value = data.get("force_offline", false)
	force_offline = force_value if typeof(force_value) == TYPE_BOOL else false
