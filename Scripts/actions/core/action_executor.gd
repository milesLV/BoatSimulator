extends Node
class_name ActionExecutor


signal action_started(instance)
signal action_completed(instance)
signal action_interrupted(instance)

signal queue_finished


# Executor lives inside Crewmate.
# Parent = actor.
@onready var actor = get_parent()


var current_action: ActionInstance = null

var queued_actions: Array[ActionInstance] = []


# ==================================================
# PUBLIC
# ==================================================

func queue_action(
	definition: ActionDefinition
) -> ActionInstance:

	var instance = ActionInstance.new(
		definition,
		actor
	)

	queued_actions.append(
		instance
	)

	if current_action == null:
		_start_next_action()

	return instance


func queue_actions(
	definitions: Array
) -> void:

	for definition in definitions:

		var instance = ActionInstance.new(
			definition,
			actor
		)

		queued_actions.append(
			instance
		)

	if current_action == null:
		_start_next_action()


func interrupt_current() -> void:

	if current_action == null:
		return

	current_action.definition.on_interrupt(
		actor,
		current_action
	)

	action_interrupted.emit(
		current_action
	)

	current_action = null


func clear_queue() -> void:

	queued_actions.clear()


func get_total_remaining_time() -> float:

	var total := 0.0

	if current_action != null:

		total += (
			current_action.duration
			- current_action.elapsed
		)

	for action in queued_actions:

		total += action.duration

	return total


# ==================================================
# PROCESS
# ==================================================

func _physics_process(
	delta: float
) -> void:

	if current_action == null:
		return

	if not current_action.started:

		current_action.started = true

		current_action.definition.on_start(
			actor,
			current_action
		)

		action_started.emit(
			current_action
		)

	current_action.elapsed += delta

	current_action.definition.on_tick(
		actor,
		current_action,
		delta
	)

	if current_action.is_complete():

		_complete_current()


# ==================================================
# INTERNAL
# ==================================================

func _complete_current() -> void:

	current_action.finished = true

	current_action.definition.on_complete(
		actor,
		current_action
	)

	action_completed.emit(
		current_action
	)

	current_action = null

	_start_next_action()


func _start_next_action() -> void:

	if queued_actions.is_empty():

		queue_finished.emit()

		return

	current_action = (
		queued_actions.pop_front()
	)
