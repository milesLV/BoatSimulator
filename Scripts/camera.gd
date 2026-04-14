extends Camera2D

const ZOOM_SPEED = Vector2(0.1, 0.1)
const MIN_ZOOM = Vector2(0.4, 0.4)
const MAX_ZOOM = Vector2(1.9, 1.9)

func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	
	if Input.is_action_just_released("ZoomIn"):
		zoom = clamp(zoom, MIN_ZOOM, MAX_ZOOM) + ZOOM_SPEED
	if Input.is_action_just_released("ZoomOut"):
		zoom = clamp(zoom, MIN_ZOOM, MAX_ZOOM) - ZOOM_SPEED
