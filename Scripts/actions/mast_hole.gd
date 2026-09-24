class_name MastHole
extends ShipHolePoint

## A mast hole lets no water in and only ever opens to grade 1, but patching one is always the
## same fixed job, however it was holed.
const REPAIR_SECONDS := 4.0


func _init() -> void:

	max_grade = 1


func repair_duration() -> float:

	return REPAIR_SECONDS
