extends Camera2D

@onready var follow_target = get_parent().get_node("Player")

const ZOOM_SPEED = Vector2(0.1, 0.1)
const MIN_ZOOM = Vector2(0.4, 0.4)
const MAX_ZOOM = Vector2(1.9, 1.9)

var is_panning := false
var is_following := true

func _process(_delta: float) -> void:

	# --------------------
	# FOLLOW PLAYER
	# --------------------
	if is_following and follow_target != null:
		global_position = follow_target.global_position

	# --------------------
	# ZOOM
	# --------------------
	if Input.is_action_just_released("ZoomIn"):
		zoom = clamp(zoom, MIN_ZOOM, MAX_ZOOM) + ZOOM_SPEED
	if Input.is_action_just_released("ZoomOut"):
		zoom = clamp(zoom, MIN_ZOOM, MAX_ZOOM) - ZOOM_SPEED

func _input(event):

	# --------------------
	# START / STOP DRAG
	# --------------------
	if event.is_action_pressed("panCamera"):
		is_panning = true
		is_following = false

	if event.is_action_released("panCamera"):
		is_panning = false

	# --------------------
	# DRAG CAMERA
	# --------------------
	if is_panning and event is InputEventMouseMotion:
		# Move opposite to mouse motion for "drag world" feel
		position -= event.relative.rotated(global_rotation) * zoom
		
	# --------------------
	# RESET CAMERA
	# --------------------
	if event.is_action_pressed("resetCameraPan"):
		is_panning = false # just in case
		is_following = true
