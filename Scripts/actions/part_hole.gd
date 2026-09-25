class_name PartHole
extends ShipHolePoint

## Lets no water in; patching is the same job however it was holed.
const REPAIR_SECONDS := 4.0


func _init() -> void:

	max_grade = 1


func repair_duration() -> float:

	return REPAIR_SECONDS
