class_name ShipDebugLog
extends RefCounted

## Channels named here stay quiet. Tests mute the noisy ones.
static var muted: Dictionary = {}


static func write(channel: StringName, message: String) -> void:
	if not muted.get(channel, false):
		print(message)


## Renders a details Dictionary as space-separated `key=value` pairs.
static func join_details(details: Dictionary) -> String:

	var parts := PackedStringArray()

	for key in details:
		parts.append("%s=%s" % [key, details[key]])

	return " ".join(parts)


static func route_failure(route_name: String, details: Dictionary = {}) -> void:

	write(&"route", "Route build failed [%s]%s" % [
		route_name,
		": " + join_details(details) if not details.is_empty() else "."
	])
