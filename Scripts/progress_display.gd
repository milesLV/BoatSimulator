class_name ProgressDisplay
extends Control

var progress := 1.0


func set_progress(value: float) -> void:

	progress = clamp(value, 0.0, 1.0)
	queue_redraw()
