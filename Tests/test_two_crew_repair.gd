extends "res://Tests/harness.gd"

const STEP := 0.1
const TIME_LIMIT := 180.0

var scenarios := [
	{
		"name": "moderate_split",
		"water": 100.0,
		"moving": false,
		"holes": {"HolePort2": 3, "HoleStarb9": 3}
	},
	{
		"name": "high_aft_mid",
		"water": 320.0,
		"moving": false,
		"holes": {
			"HolePort1": 4,
			"HolePort2": 3,
			"HoleStarb1": 4,
			"HoleStarb2": 3
		}
	},
	{
		"name": "high_mixed_moving",
		"water": 300.0,
		"moving": true,
		"holes": {
			"HolePort3": 4,
			"HoleStarb4": 3,
			"HolePort8": 4,
			"HoleBow": 4
		}
	},
	{
		"name": "near_sink_lower",
		"water": 430.0,
		"moving": false,
		"holes": {
			"HolePort7": 5,
			"HolePort8": 5,
			"HoleStarb9": 5,
			"HoleBow": 5
		}
	},
	{
		"name": "near_sink_mixed",
		"water": 420.0,
		"moving": true,
		"holes": {
			"HolePort1": 5,
			"HoleStarb1": 5,
			"HolePort8": 4,
			"HoleStarb9": 4
		}
	},
	{
		"name": "mixed_grade_priority",
		"water": 490.0,
		"moving": false,
		"holes": {
			"HolePort7": 1,
			"HoleStarb7": 1,
			"HolePort8": 1,
			"HoleStarb8": 1,
			"HoleBow": 5
		}
	},
	{
		"name": "mid_threshold_teamwork",
		"water": 280.0,
		"moving": false,
		"holes": {
			"HolePort1": 5,
			"HolePort2": 5,
			"HoleStarb1": 5,
			"HoleStarb2": 5
		}
	},
	{
		"name": "extreme_combined_moving",
		"water": 470.0,
		"moving": true,
		"holes": {
			"HolePort1": 5,
			"HoleStarb1": 5,
			"HolePort8": 5,
			"HoleStarb9": 5
		}
	}
]


func _run() -> void:

	ShipDebugLog.muted[&"crew"] = true
	ShipDebugLog.muted[&"repair"] = true
	ShipDebugLog.muted[&"bail"] = true

	var failures: Array[String] = []

	for scenario in scenarios:
		var result = await _run_scenario(scenario)
		print(JSON.stringify(result))

		if not result["survived"] or not result["resolved"]:
			failures.append(result["name"])

	if not failures.is_empty():
		push_error("Two-crew repair failures: %s" % ", ".join(failures))

	quit(failures.size())


func _run_scenario(scenario: Dictionary) -> Dictionary:

	var ship: Sloop = load("res://Scenes/Sloop.tscn").instantiate()
	root.add_child(ship)
	await process_frame
	ship.process_mode = Node.PROCESS_MODE_DISABLED

	for hole in ship.action_points.holes:
		hole.set_grade(int(scenario["holes"].get(String(hole.name), 0)))

	ship.health_system.water_level = float(scenario["water"])
	ship.velocity = Vector2(100.0, 0.0) if scenario["moving"] else Vector2.ZERO

	var counts := {}
	var crewmates = ship.get_crewmates()

	for crewmate in crewmates:
		counts[String(crewmate.name)] = {"repair": 0, "bail": 0}
		crewmate.action_executor.action_completed.connect(
			func(instance):
				if instance.definition is RepairHoleAction:
					counts[String(crewmate.name)]["repair"] += 1
				elif (
					instance.definition is BailWaterAction
					or (
						instance.definition is MoveAndBailWaterAction
						and not (instance.definition is MoveAndThrowBucketWaterAction)
					)
				):
					counts[String(crewmate.name)]["bail"] += 1
		)
		ship.repair_duty_controller.assign_crewmate(crewmate)

	var elapsed := 0.0
	var peak_water = ship.health_system.water_level

	while elapsed < TIME_LIMIT and not ship.is_sunk():
		ship.health_system.physics_process(STEP)

		for crewmate in crewmates:
			crewmate.action_executor._physics_process(STEP)

		elapsed += STEP
		peak_water = max(peak_water, ship.health_system.water_level)

		if _is_resolved(ship):
			break

	var result = {
		"name": scenario["name"],
		"survived": not ship.is_sunk(),
		"resolved": _is_resolved(ship),
		"seconds": snapped(elapsed, 0.1),
		"peak_water": snapped(peak_water, 0.1),
		"final_water": snapped(ship.health_system.water_level, 0.1),
		"work": counts
	}

	ship.queue_free()
	await process_frame
	return result


func _is_resolved(ship: Sloop) -> bool:

	if ship.health_system.water_level > 0.01:
		return false

	for hole in ship.action_points.holes:
		if hole.grade > ShipHolePoint.MIN_GRADE:
			return false

	return true
