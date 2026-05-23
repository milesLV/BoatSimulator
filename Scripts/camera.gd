extends Camera2D

var follow_target: Node2D = null

const ZOOM_STEP = Vector2(0.1, 0.1)
const KEY_ZOOM_SPEED = Vector2(1.0, 1.0)
const TRACKPAD_ZOOM_SPEED = Vector2(1.5, 1.5)
const TRACKPAD_SCROLL_ZOOM_SPEED = Vector2(0.01, 0.01)
const MIN_ZOOM = Vector2(0.4, 0.4)
const MAX_ZOOM = Vector2(1.9, 1.9)

var is_panning := false
var is_following := true

func _ready() -> void:

	follow_target = _get_player_target()

func _process(delta: float) -> void:
	if follow_target == null:
		follow_target = _get_player_target()

	# following player
	if is_following and follow_target != null:
		global_position = follow_target.global_position

	var zoom_input := 0.0

	if Input.is_action_pressed("ZoomIn"):
		zoom_input += 1.0

	if Input.is_action_pressed("ZoomOut"):
		zoom_input -= 1.0

	if zoom_input != 0.0:
		_apply_zoom(
			KEY_ZOOM_SPEED * zoom_input * delta
		)

func _input(event):
	if event is InputEventMagnifyGesture:
		# Pinching out increases the gesture factor, so invert it to match Camera2D zoom.
		_apply_zoom(
			TRACKPAD_ZOOM_SPEED * (1.0 - event.factor)
		)
		return

	if event is InputEventPanGesture:
		_apply_zoom(
			TRACKPAD_SCROLL_ZOOM_SPEED * event.delta.y
		)
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(
				-ZOOM_STEP
			)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(
				ZOOM_STEP
			)

	# starting drag
	if event.is_action_pressed("panCamera"):
		is_panning = true
		is_following = false
	
	#stopping
	if event.is_action_released("panCamera"):
		is_panning = false

	# drag camera
	if is_panning and event is InputEventMouseMotion:
		position -= event.relative.rotated(global_rotation) * zoom
	
	# reset camera
	if event.is_action_pressed("resetCameraPan"):
		is_panning = false # just in case
		is_following = true


func _apply_zoom(
	zoom_delta: Vector2
) -> void:

	zoom = clamp(
		zoom + zoom_delta,
		MIN_ZOOM,
		MAX_ZOOM
	)


func _get_player_target() -> Node2D:

	var game_map = get_tree().current_scene

	if (
		game_map == null
		or not game_map.has_method(
			"get_player_ship"
		)
	):
		return null

	return game_map.get_player_ship()
