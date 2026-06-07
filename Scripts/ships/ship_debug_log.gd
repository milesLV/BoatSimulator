class_name ShipDebugLog
extends RefCounted

static var bail_enabled := true
static var anchor_enabled := true
static var cannon_enabled := true
static var crew_enabled := true
static var repair_enabled := true
static var route_enabled := true


static func bail(message: String) -> void:
	if bail_enabled:
		print(message)


static func anchor(message: String) -> void:
	if anchor_enabled:
		print(message)


static func cannon(message: String) -> void:
	if cannon_enabled:
		print(message)


static func crew(message: String) -> void:
	if crew_enabled:
		print(message)


static func repair(message: String) -> void:
	if repair_enabled:
		print(message)


static func route_failure(route_name: String, details: Dictionary = {}) -> void:
	if not route_enabled:
		return

	var detail_text := ""

	for key in details.keys():
		if detail_text != "":
			detail_text += " "

		detail_text += "%s=%s" % [
			String(key),
			String(details[key])
		]

	if detail_text == "":
		print("Route build failed [%s]." % route_name)
		return

	print("Route build failed [%s]: %s" % [route_name, detail_text])
