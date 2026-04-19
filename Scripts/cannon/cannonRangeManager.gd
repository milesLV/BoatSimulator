@tool
extends Node2D

const MAX_RANGE := 1200.0
const SYMMETRICAL_ANGLE := 45.0
const STEP := 2.5
const SEGMENT_COUNT := 3
const GAP := 0.01

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

	var seg_size := MAX_RANGE / SEGMENT_COUNT

	for i in range(segments.size()):
		var seg = segments[i]

		var inner := i * seg_size
		var outer := (i + 1) * seg_size

		# Apply gap ONLY to inner (except first segment)
		if i > 0:
			inner += GAP

		seg.set("INNER_RADIUS", inner)
		seg.set("OUTER_RADIUS", outer)
		seg.set("START_ANGLE", SYMMETRICAL_ANGLE)
		seg.set("STEP", STEP)

		seg.rebuild()
