class_name ShipHolePoint
extends ShipActionPoint

const MIN_GRADE := 0
const MAX_GRADE := 5
@export_range(MIN_GRADE, MAX_GRADE) # exporting just for now for testing, delete later
var grade: int = MIN_GRADE # default = no hole

func set_grade(
	new_grade: int
) -> void:

	grade = clampi(
		new_grade,
		MIN_GRADE,
		MAX_GRADE
	)
