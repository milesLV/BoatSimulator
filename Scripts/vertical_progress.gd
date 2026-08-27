class_name VerticalProgress
extends ProgressDisplay

const BAR_RECT := Rect2(130.0, 10.0, 30.0, 140.0)

enum Source { ANCHOR, MAST }

@export var source := Source.ANCHOR:
	set(value):
		source = value

		if is_node_ready():
			label.text = Source.keys()[source].capitalize()

@onready var label: Label = $Text/Label
@onready var percentage: Label = $Text/Percentage


func _ready() -> void:

	label.text = Source.keys()[source].capitalize()
	set_progress(progress)


func _process(_delta: float) -> void:

	if source != Source.ANCHOR:
		return

	var ship = GlobalShipRegistry.get_player_ship_from_tree(get_tree())

	if ship == null or ship.anchor_system == null:
		hide()
		return

	set_progress(1.0 - ship.anchor_system.drop_progress)


func set_progress(value: float) -> void:

	super.set_progress(value)

	if is_node_ready():
		percentage.text = "%d%%" % roundi(progress * 100.0)
		visible = progress < 1.0


func _draw() -> void:

	draw_rect(BAR_RECT, Color(1.0, 1.0, 1.0, 0.2))
	var fill_height = BAR_RECT.size.y * progress
	draw_rect(Rect2(
		BAR_RECT.position + Vector2(0.0, BAR_RECT.size.y - fill_height),
		Vector2(BAR_RECT.size.x, fill_height)
	), Color.WHITE)
	draw_rect(BAR_RECT, Color.WHITE, false, 2.0)
