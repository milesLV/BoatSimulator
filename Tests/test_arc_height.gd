extends "res://Tests/harness.gd"

# godot --headless --script Tests/test_arc_height.gd
#
# The drawn arc: flat at launch, full height halfway, flat again on landing and after it.


func _run() -> void:

	check(is_zero_approx(Cannonball.arc_height(0.0)))
	check(is_equal_approx(Cannonball.arc_height(0.5), 1.0))
	check(is_zero_approx(Cannonball.arc_height(1.0)))
	check(is_zero_approx(Cannonball.arc_height(1.4)), "a miss past its aim point stays at deck height")
	check(Cannonball.arc_height(0.25) < Cannonball.arc_height(0.5))

	finish("test_arc_height")
