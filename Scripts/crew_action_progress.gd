extends ProgressDisplay

const PROGRESS_WIDTH := 20.0
const TICK_LENGTH := 40.0
const START_ANGLE := -PI / 2.0

@export var radius := 55.0
@export var font_size_ratio := 0.6
@export var show_other_crewmate := false
@onready var countdown: Label = $Countdown

var durations: Array = []
var total_duration := 0.0


func _ready() -> void:

	countdown.add_theme_font_size_override("font_size", roundi(radius * font_size_ratio))
	hide()

func _process(_delta: float) -> void:

	var ship = GlobalShipRegistry.get_player_ship_from_tree(get_tree())
	var actor = get_displayed_crewmate(ship)
	var executor = actor.action_executor if actor != null else null

	if executor == null or ship.action_planner == null or not executor.has_actions():
		hide()
		return

	var timing = ship.action_planner.route_planner.get_plan_timing(actor, executor.plan_actions)
	total_duration = timing["total_duration"]

	if total_duration <= 0.0:
		hide()
		return

	durations = timing["durations"]
	set_progress(timing["elapsed"] / total_duration)
	countdown.text = "%.1f" % timing["remaining"]
	show()


func get_displayed_crewmate(ship):

	if ship == null:
		return null

	var selected = ship.get_current_crewmate()

	if not show_other_crewmate:
		return selected

	for crewmate in ship.get_crewmates():
		if crewmate != selected:
			return crewmate

	return null


func _draw() -> void:

	var center = size / 2.0
	draw_arc(
		center,
		radius,
		0.0,
		TAU,
		64,
		Color(1.0, 1.0, 1.0, 0.2),
		PROGRESS_WIDTH,
		true
	)

	if progress > 0.0:
		draw_arc(
			center,
			radius,
			START_ANGLE,
			START_ANGLE + TAU * progress,
			64,
			Color.WHITE,
			PROGRESS_WIDTH,
			true
		)

	var elapsed := 0.0

	for i in range(durations.size() - 1):
		elapsed += durations[i]
		var angle = START_ANGLE + TAU * elapsed / total_duration
		var direction = Vector2.from_angle(angle)
		draw_line(
			center + direction * (radius - TICK_LENGTH / 2.0),
			center + direction * (radius + TICK_LENGTH / 2.0),
			Color.BLACK,
			4.5,
			true
		)
