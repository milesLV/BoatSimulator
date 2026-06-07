class_name ContinueBailingAction
extends ActionDefinition

var drain_to_zero := false


func _init(new_drain_to_zero := false) -> void:

	action_id = "continue_bailing"
	base_duration = 0.0
	progress_policy = ProgressPolicy.ONE_SHOT
	drain_to_zero = new_drain_to_zero


func on_complete(
	actor,
	instance
) -> void:

	if (
		actor == null
		or actor.ship == null
		or actor.ship.action_planner == null
		or actor.action_executor == null
	):
		super.on_complete(
			actor,
			instance
		)
		return

	var repair_duty_controller = actor.ship.get("repair_duty_controller")

	if (
		repair_duty_controller != null
		and repair_duty_controller.is_repair_duty_crewmate(actor)
	):
		super.on_complete(
			actor,
			instance
		)
		return

	var next_actions = actor.ship.action_planner.build_bail_water(
		actor,
		drain_to_zero
	)

	if not next_actions.is_empty():
		actor.action_executor.queue_actions(next_actions)

	super.on_complete(
		actor,
		instance
	)
