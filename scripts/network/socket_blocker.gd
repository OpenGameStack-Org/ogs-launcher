## SocketBlocker: Guarded socket access for the launcher.
##
## Provides a single entry point for creating sockets. When offline is active,
## it blocks all socket creation attempts. Online behavior returns a real
## socket object and optionally attempts a connection.

extends RefCounted
class_name SocketBlocker

const OfflineEnforcer = preload("res://scripts/network/offline_enforcer.gd")
const Logger = preload("res://scripts/logging/logger.gd")

## Default allowlist for outbound connections.
static var _allowed_hosts: Array[String] = ["localhost", "127.0.0.1"]
static var _allowed_ports: Array[int] = []

## Error codes for socket operations.
enum SocketError {
	SUCCESS = 0,
	OFFLINE_BLOCKED = 1,
	CONNECT_FAILED = 2,
}

static func open_tcp_client(host: String, port: int, connect: bool = true) -> Dictionary:
	"""Guards TCP client creation based on offline state.
	Parameters:
	  host (String): Target host
	  port (int): Target port
	  connect (bool): If true, attempt a connection immediately
	Returns:
	  Dictionary: {"success": bool, "error_code": int, "error_message": String, "client": StreamPeerTCP}
	"""
	var guard = OfflineEnforcer.guard_network_call("tcp:%s:%d" % [host, port])
	if not guard["allowed"]:
		Logger.warn("socket_blocked", {"component": "network", "reason": "offline", "host": host, "port": port})
		return {
			"success": false,
			"error_code": SocketError.OFFLINE_BLOCKED,
			"error_message": guard["error_message"],
			"client": null
		}
	var allow_check = _is_allowed(host, port)
	if not allow_check["allowed"]:
		Logger.warn("socket_blocked", {"component": "network", "reason": "allowlist", "host": host, "port": port})
		return {
			"success": false,
			"error_code": SocketError.CONNECT_FAILED,
			"error_message": allow_check["error_message"],
			"client": null
		}
	var peer = StreamPeerTCP.new()
	if not connect:
		return {
			"success": true,
			"error_code": SocketError.SUCCESS,
			"error_message": "",
			"client": peer
		}
	var err = peer.connect_to_host(host, port)
	if err != OK:
		Logger.error("socket_connect_failed", {"component": "network", "host": host, "port": port})
		return {
			"success": false,
			"error_code": SocketError.CONNECT_FAILED,
			"error_message": "Failed to connect (%s:%d). Error: %d" % [host, port, err],
			"client": peer
		}
	Logger.info("socket_connected", {"component": "network", "host": host, "port": port})
	return {
		"success": true,
		"error_code": SocketError.SUCCESS,
		"error_message": "",
		"client": peer
	}

## Sets an explicit allowlist for outbound connections.
static func set_allowlist(hosts: Array[String], ports: Array[int] = []) -> void:
	_allowed_hosts = hosts
	_allowed_ports = ports

## Resets the allowlist to defaults.
static func reset_allowlist() -> void:
	_allowed_hosts = ["localhost", "127.0.0.1"]
	_allowed_ports = []

static func _is_allowed(host: String, port: int) -> Dictionary:
	var normalized_host = host.strip_edges().to_lower()
	if _allowed_hosts.size() > 0 and not _allowed_hosts.has(normalized_host):
		return {
			"allowed": false,
			"error_message": "Host not allowed: %s" % host
		}
	if _allowed_ports.size() > 0 and not _allowed_ports.has(port):
		return {
			"allowed": false,
			"error_message": "Port not allowed: %d" % port
		}
	return {"allowed": true, "error_message": ""}
