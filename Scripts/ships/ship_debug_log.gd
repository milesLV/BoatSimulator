class_name ShipDebugLog
extends RefCounted

static var muted: Dictionary = {}


static func write(channel: StringName, message: String) -> void:
	if not muted.get(channel, false):
		print(message)
