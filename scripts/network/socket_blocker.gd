## SocketBlocker: Guarded socket access for the launcher.
##
## Provides a single entry point for creating sockets. When offline is active,
## it blocks all socket creation attempts. Online behavior returns a real
## socket object and optionally attempts a connection.

extends RefCounted
class_name SocketBlocker

const OfflineEnforcer = preload("res://scripts/network/offline_enforcer.gd")

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
		return {
			"success": false,
			"error_code": SocketError.OFFLINE_BLOCKED,
			"error_message": guard["error_message"],
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
		return {
			"success": false,
			"error_code": SocketError.CONNECT_FAILED,
			"error_message": "Failed to connect (%s:%d). Error: %d" % [host, port, err],
			"client": peer
		}
	return {
		"success": true,
		"error_code": SocketError.SUCCESS,
		"error_message": "",
		"client": peer
	}
