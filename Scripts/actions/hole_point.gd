class_name ShipHolePoint
extends ShipActionPoint

signal grade_changed(
	hole: ShipHolePoint,
	old_grade: int,
	new_grade: int
)

const MIN_GRADE := 0
const MAX_GRADE := 5
const DEBUG_RADIUS := 5.0

@export_range(MIN_GRADE, MAX_GRADE) # exporting just for now for testing, delete later
var grade: int = MIN_GRADE # default = no hole


func _draw() -> void:

	if grade <= MIN_GRADE:
		return

	draw_circle(
		Vector2.ZERO,
		DEBUG_RADIUS,
		Color(
			1.0,
			0.0,
			0.0,
			float(grade) / float(MAX_GRADE)
		)
	)


func set_grade(new_grade: int) -> void:

	var clamped_grade = clampi(
		new_grade,
		MIN_GRADE,
		MAX_GRADE
	)

	if grade == clamped_grade:
		queue_redraw()
		return

	var old_grade = grade
	grade = clamped_grade
	grade_changed.emit(
		self,
		old_grade,
		grade
	)

	queue_redraw()


func add_grade(amount: int) -> void:

	set_grade(grade + amount)


func repair_fully() -> void:

	set_grade(MIN_GRADE)
