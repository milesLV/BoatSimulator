extends SceneTree

# Shared boot for the headless suites: `godot --headless --script Tests/test_x.gd`
# instances the script as the SceneTree, so _run has to be deferred past _init.


func _init() -> void:

	call_deferred("_run")


## Lets queue_free, _ready and other deferred work land before assertions.
func _settle() -> void:

	for i in 4:
		await process_frame


func _run() -> void:

	pass
