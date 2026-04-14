@tool
extends Node2D

var _max_range: float = 1200.0
@export var max_range: float:
	get: return _max_range
	set(value):
		_max_range = value
		rebuild()

var _symmetrical_angle: float = 45.0
@export var symmetrical_angle: float:
	get: return _symmetrical_angle
	set(value):
		_symmetrical_angle = value
		rebuild()

var _step: float = 2.5
@export var step: float:
	get: return _step
	set(value):
		_step = value
		rebuild()
		
var _segment_count: int = 3
@export var segment_count: int:
	get: return _segment_count
	set(value):
		_segment_count = value
		rebuild()

var _gap: float = 0.01
@export var gap: float:
	get: return _gap
	set(value):
		_gap = value
		rebuild()

var segments: Array = []

func _ready():
	_collect_segments()
	rebuild()

func _collect_segments():
	segments.clear()

	for child in get_children():
		if child is Area2D and child.get_child_count() > 0:
			var poly = child.get_child(0)
			if poly is CollisionPolygon2D:
				segments.append(poly)

func rebuild():
	if !is_inside_tree():
		return

	if segments.is_empty():
		_collect_segments()

	if segments.is_empty():
		return

	var seg_size := max_range / segment_count

	for i in range(segments.size()):
		var seg = segments[i]

		var inner := i * seg_size
		var outer := (i + 1) * seg_size

		# Apply gap ONLY to inner (except first segment)
		if i > 0:
			inner += gap

		seg.set("inner_radius", inner)
		seg.set("outer_radius", outer)
		seg.set("start_angle", symmetrical_angle)
		seg.set("step", step)

		seg.rebuild()

func get_max_range() -> float:
	return _max_range
