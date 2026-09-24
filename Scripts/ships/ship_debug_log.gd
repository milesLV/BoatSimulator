class_name ShipDebugLog
extends RefCounted

## Channels named here stay quiet. Tests mute the noisy ones.
static var muted: Dictionary = {}


static func write(channel: StringName, message: String) -> void:
	if not muted.get(channel, false):
		print(message)


static func route_failure(route_name: String, details: Dictionary = {}) -> void:

	write(&"route", "Route build failed [%s] %s" % [route_name, details])
