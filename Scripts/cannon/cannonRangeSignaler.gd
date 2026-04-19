@tool
extends Area2D

var ring_index := 0

signal target_entered(body, ring_index)
signal target_exited(body, ring_index)

func _ready():
	# Automatically set up indexes for rings
	if Engine.is_editor_hint():
		var parent = get_parent()
		if parent:
			ring_index = get_index()
		
	# Ensure signals are connected (only once)
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		body_entered.connect(_on_body_entered)
	if not is_connected("body_exited", Callable(self, "_on_body_exited")):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	print("Body entered:", body)
	if body == get_parent().get_parent():
		return
	target_entered.emit(body, ring_index)

func _on_body_exited(body):
	target_exited.emit(body)
