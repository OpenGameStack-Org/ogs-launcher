## ToolExtractor: Handles extraction of downloaded tools into the library.
##
## Responsible for unzipping tool archives and placing their contents into
## the proper library structure. Handles nested zip structures (where the
## actual tool binaries are in a subdirectory of the archive).
##
## Extraction workflow:
##   1. Download tool .zip to a temporary location
##   2. Call extract_to_library() with the .zip path
##   3. Extractor unzips to [LIBRARY_ROOT]/[tool_id]/[version]/
##   4. If extraction succeeds, temp .zip is deleted
##   5. LibraryManager can then discover the tool
##
## Example nested structure handling:
##   Archive: godot-4.3-windows-x64.zip
##   Contents:
##     godot-4.3-windows-x64/
##       godot.exe
##       ... other files
##   Result after extraction:
##     [LIBRARY_ROOT]/godot/4.3/godot.exe
##
## Usage:
##   var extractor = ToolExtractor.new()
##   var result = extractor.extract_to_library(
##       "C:/Downloads/godot-4.3.zip",
##       "godot",
##       "4.3"
##   )
##   if result.success:
##       print("Tool ready at: " + result.tool_path)

extends RefCounted
class_name ToolExtractor

const PathResolver = preload("res://scripts/library/path_resolver.gd")
const Logger = preload("res://scripts/logging/logger.gd")

## Error codes for extraction failures
enum ExtractionError {
	SUCCESS = 0,
	SOURCE_NOT_FOUND = 1,
	INVALID_ARCHIVE = 2,
	EXTRACTION_FAILED = 3,
	CLEANUP_FAILED = 4,
	INVALID_PARAMETERS = 5,
}

var path_resolver: PathResolver

func _init():
	path_resolver = PathResolver.new()

## Extracts a tool archive to the library.
##
## Parameters:
##   archive_path (String): Full path to the .zip file
##   tool_id (String): Tool identifier (e.g., "godot")
##   version (String): Version string (e.g., "4.3")
##
## Returns:
##   Dictionary: {
##       "success": bool,
##       "error_code": int,
##       "error_message": String,
##       "tool_path": String (set if success),
##       "extracted_files": int (count of files extracted)
##   }
func extract_to_library(archive_path: String, tool_id: String, version: String) -> Dictionary:
	var result = {
		"success": false,
		"error_code": ExtractionError.INVALID_PARAMETERS,
		"error_message": "",
		"tool_path": "",
		"extracted_files": 0
	}
	
	# Validate parameters
	if archive_path.is_empty() or tool_id.is_empty() or version.is_empty():
		result["error_message"] = "Missing required parameters"
		Logger.error("extraction_failed", {
			"component": "library",
			"reason": "invalid parameters",
			"tool_id": tool_id,
			"version": version
		})
		return result
	
	# Check archive exists
	if not FileAccess.file_exists(archive_path):
		result["error_code"] = ExtractionError.SOURCE_NOT_FOUND
		result["error_message"] = "Archive file not found: %s" % archive_path
		Logger.error("extraction_failed", {
			"component": "library",
			"reason": "archive not found",
			"archive": archive_path,
			"tool_id": tool_id
		})
		return result
	
	# Get target directory
	var target_dir = path_resolver.get_tool_path(tool_id, version)
	if target_dir.is_empty():
		result["error_code"] = ExtractionError.INVALID_PARAMETERS
		result["error_message"] = "Failed to resolve target directory"
		Logger.error("extraction_failed", {
			"component": "library",
			"reason": "path resolution failed",
			"tool_id": tool_id,
			"version": version
		})
		return result
	
	# Create target directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(target_dir):
		var err = DirAccess.make_dir_absolute(target_dir)
		if err != OK:
			result["error_code"] = ExtractionError.EXTRACTION_FAILED
			result["error_message"] = "Failed to create target directory"
			Logger.error("extraction_failed", {
				"component": "library",
				"reason": "mkdir failed",
				"target": target_dir,
				"tool_id": tool_id
			})
			return result
	
	# Perform extraction
	var extraction_result = _extract_zip(archive_path, target_dir)
	if not extraction_result["success"]:
		result["error_code"] = ExtractionError.EXTRACTION_FAILED
		result["error_message"] = extraction_result["error"]
		Logger.error("extraction_failed", {
			"component": "library",
			"reason": extraction_result["error"],
			"archive": archive_path,
			"tool_id": tool_id,
			"version": version
		})
		return result
	
	# Try to clean up the archive
	var cleanup_err = _cleanup_archive(archive_path)
	if cleanup_err != OK:
		Logger.warn("archive_cleanup_failed", {
			"component": "library",
			"archive": archive_path,
			"tool_id": tool_id,
			"version": version
		})
		# Not a fatal error; log and continue
	
	result["success"] = true
	result["error_code"] = ExtractionError.SUCCESS
	result["tool_path"] = target_dir
	result["extracted_files"] = extraction_result["file_count"]
	
	Logger.info("tool_extracted", {
		"component": "library",
		"tool_id": tool_id,
		"version": version,
		"target": target_dir,
		"file_count": result["extracted_files"]
	})
	
	return result

## Validates that an archive is a valid zip file.
## Parameters:
##   archive_path (String): Path to file to validate
## Returns:
##   Dictionary: {"valid": bool, "error": String}
func validate_archive(archive_path: String) -> Dictionary:
	if not FileAccess.file_exists(archive_path):
		return {"valid": false, "error": "File not found"}
	
	# MVP: Simple existence check. Phase 2 will validate zip structure.
	# For now, assume .zip extension means valid
	if archive_path.ends_with(".zip"):
		return {"valid": true, "error": ""}
	else:
		return {"valid": false, "error": "File does not end with .zip extension"}

# Private helper: extract zip using ZipReader
# MVP: Stubbed for Phase 2 - actual implementation requires ZipReader integration
func _extract_zip(archive_path: String, target_dir: String) -> Dictionary:
	var result = {
		"success": false,
		"error": "",
		"file_count": 0
	}
	
	# TODO: Phase 2 - Implement actual zip extraction using ZipReader
	# For MVP, this is stubbed to allow testing library manager without extraction
	Logger.warn("zip_extraction_stubbed", {
		"component": "library",
		"archive": archive_path,
		"reason": "Phase 2 implementation"
	})
	
	result["error"] = "Zip extraction not yet implemented (Phase 2)"
	return result

# Private helper: delete archive after successful extraction
func _cleanup_archive(archive_path: String) -> Error:
	if FileAccess.file_exists(archive_path):
		return DirAccess.remove_absolute(archive_path)
	return OK
