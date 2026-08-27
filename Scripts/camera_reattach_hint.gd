extends Label

const REATTACH_ACTION := "resetCameraPan"

func _ready() -> void:

	text = "Press %s to focus on ship" % InputMap.action_get_events(REATTACH_ACTION)[0].as_text()


func _process(_delta: float) -> void:

	var camera := get_viewport().get_camera_2d()

	visible = camera != null and not camera.is_following
