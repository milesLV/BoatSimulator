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

func queue_action(definition: ActionDefinition) -> ActionInstance:

	var instance = ActionInstance.new(
		definition,
		actor
	)

	queued_actions.append(instance)

	if current_action == null:
		_start_next_action()

	return instance


func queue_actions(definitions: Array) -> void:

	for definition in definitions:

		var instance = ActionInstance.new(
			definition,
			actor
		)

		queued_actions.append(instance)

	if current_action == null:
		_start_next_action()


func interrupt_current() -> void:

	if current_action == null:
		return

	current_action.definition.apply_interrupt_policy(
		actor,
		current_action
	)

	current_action.definition.on_interrupt(
		actor,
		current_action
	)

	action_interrupted.emit(current_action)

	current_action = null


func clear_queue() -> void:

	queued_actions.clear()


func has_actions() -> bool:

	return (
		current_action != null
		or not queued_actions.is_empty()
	)


func cancel_plan() -> bool:

	var had_actions = has_actions()

	interrupt_current()
	clear_queue()

	return had_actions


func get_total_remaining_time() -> float:

	var total := 0.0

	if current_action != null:

		total += current_action.get_remaining_time(actor)

	for action in queued_actions:

		total += action.get_remaining_time(actor)

	return total


# ==================================================
# PROCESS
# ==================================================

func _physics_process(delta: float) -> void:

	if current_action == null:
		return


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

	_finish_current_action()

	_start_next_action()


func _start_next_action() -> void:

	while current_action == null:

		if queued_actions.is_empty():
			queue_finished.emit()

			return


		current_action = (
			queued_actions.pop_front()
		)


		current_action.begin(actor)


		current_action.definition.on_start(
			actor,
			current_action
		)


		action_started.emit(current_action)

		if not current_action.is_complete():
			return

		_finish_current_action()


func _finish_current_action() -> void:

	var completed_action = current_action

	completed_action.finished = true

	completed_action.definition.on_complete(
		actor,
		completed_action
	)

	action_completed.emit(completed_action)

	current_action = null
