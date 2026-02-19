## ToolExtractor Tests
##
## Unit tests for the ToolExtractor module.
## Tests cover archive validation and extraction logic.

extends RefCounted
class_name ToolExtractorTests

func run() -> Dictionary:
	var results = {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	
	var tests = [
		{"name": "test_extract_to_library_returns_dict", "func": test_extract_to_library_returns_dict},
		{"name": "test_extract_fails_with_missing_archive", "func": test_extract_fails_with_missing_archive},
		{"name": "test_extract_fails_with_invalid_parameters", "func": test_extract_fails_with_invalid_parameters},
		{"name": "test_validate_archive_returns_dict", "func": test_validate_archive_returns_dict},
		{"name": "test_validate_archive_fails_for_missing", "func": test_validate_archive_fails_for_missing},
	]
	
	for test in tests:
		var result = test.func.call()
		if result["passed"]:
			results.passed += 1
		else:
			results.failed += 1
			if result.has("error"):
				results.failures.append("%s: %s" % [test.name, result["error"]])
			else:
				results.failures.append("%s: unknown error" % test.name)
	return results

func test_extract_to_library_returns_dict() -> Dictionary:
	var extractor = ToolExtractor.new()
	
	# Call with missing archive (will fail, but tests the return structure)
	var result = extractor.extract_to_library("nonexistent.zip", "godot", "4.3")
	
	if not result.has("success"):
		return {"passed": false, "error": "Result should have 'success' key"}
	
	if not result.has("error_code"):
		return {"passed": false, "error": "Result should have 'error_code' key"}
	
	if not result.has("error_message"):
		return {"passed": false, "error": "Result should have 'error_message' key"}
	
	if not result.has("tool_path"):
		return {"passed": false, "error": "Result should have 'tool_path' key"}
	
	if not result.has("extracted_files"):
		return {"passed": false, "error": "Result should have 'extracted_files' key"}
	
	return {"passed": true}

func test_extract_fails_with_missing_archive() -> Dictionary:
	var extractor = ToolExtractor.new()
	var result = extractor.extract_to_library("nonexistent_archive_xyz.zip", "godot", "4.3")
	
	if result["success"]:
		return {"passed": false, "error": "Should fail for missing archive"}
	
	if result["error_code"] != ToolExtractor.ExtractionError.SOURCE_NOT_FOUND:
		return {"passed": false, "error": "Should set SOURCE_NOT_FOUND error code"}
	
	if result["error_message"].is_empty():
		return {"passed": false, "error": "Should set error message"}
	
	return {"passed": true}

func test_extract_fails_with_invalid_parameters() -> Dictionary:
	var extractor = ToolExtractor.new()
	
	# Test with empty tool_id
	var result = extractor.extract_to_library("test.zip", "", "4.3")
	
	if result["success"]:
		return {"passed": false, "error": "Should fail for empty tool_id"}
	
	if result["error_code"] != ToolExtractor.ExtractionError.INVALID_PARAMETERS:
		return {"passed": false, "error": "Should set INVALID_PARAMETERS error code"}
	
	# Test with empty version
	result = extractor.extract_to_library("test.zip", "godot", "")
	
	if result["success"]:
		return {"passed": false, "error": "Should fail for empty version"}
	
	if result["error_code"] != ToolExtractor.ExtractionError.INVALID_PARAMETERS:
		return {"passed": false, "error": "Should set INVALID_PARAMETERS error code"}
	
	return {"passed": true}

func test_validate_archive_returns_dict() -> Dictionary:
	var extractor = ToolExtractor.new()
	var result = extractor.validate_archive("nonexistent.zip")
	
	if not result.has("valid"):
		return {"passed": false, "error": "Result should have 'valid' key"}
	
	if not result.has("error"):
		return {"passed": false, "error": "Result should have 'error' key"}
	
	return {"passed": true}

func test_validate_archive_fails_for_missing() -> Dictionary:
	var extractor = ToolExtractor.new()
	var result = extractor.validate_archive("nonexistent_file_xyz.zip")
	
	if result["valid"]:
		return {"passed": false, "error": "Should be invalid for missing file"}
	
	if result["error"].is_empty():
		return {"passed": false, "error": "Should have error message"}
	
	return {"passed": true}
