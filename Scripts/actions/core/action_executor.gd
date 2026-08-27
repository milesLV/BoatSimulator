extends Node
class_name ActionExecutor


signal action_completed(instance)
signal queue_finished


@onready var actor = get_parent()


var current_action: ActionInstance = null

var queued_actions: Array[ActionInstance] = []
var plan_actions: Array[ActionInstance] = []


func queue_actions(definitions: Array) -> void:

	for definition in definitions:
		if not (definition is ActionDefinition):
			push_warning("Ignored invalid action definition.")
			continue

		var instance = ActionInstance.new(definition)

		queued_actions.append(instance)
		plan_actions.append(instance)

	if current_action == null:
		_start_next_action()


func interrupt_current() -> void:

	if current_action == null:
		return

	current_action.definition.apply_interrupt_policy(actor, current_action)

	current_action.definition.on_interrupt(actor, current_action)

	current_action = null


func has_actions() -> bool:

	return current_action != null or not queued_actions.is_empty()


func cancel_plan() -> bool:

	var had_actions = has_actions()

	interrupt_current()
	queued_actions.clear()
	plan_actions.clear()

	return had_actions


func _physics_process(delta: float) -> void:

	var remaining_delta := delta

	while remaining_delta > 0.0:
		if current_action == null:
			_start_next_action()

		if current_action == null:
			return

		var action_delta = remaining_delta

		if current_action.duration >= 0.0:
			action_delta = min(
				remaining_delta,
				max(current_action.duration - current_action.elapsed, 0.0)
			)

		current_action.elapsed += action_delta

		current_action.definition.on_tick(actor, current_action, action_delta)

		if not current_action.is_complete():
			return

		remaining_delta -= action_delta

		_finish_current_action()

		if remaining_delta <= 0.0:
			_start_next_action()
			return


func _start_next_action() -> void:

	while current_action == null:

		if queued_actions.is_empty():
			plan_actions.clear()
			queue_finished.emit()

			return

		current_action = queued_actions.pop_front()
		current_action.begin(actor)
		current_action.definition.on_start(actor, current_action)

		if not current_action.is_complete():
			return

		_finish_current_action()


func _finish_current_action() -> void:

	var completed_action = current_action

	completed_action.finished = true

	completed_action.definition.on_complete(actor, completed_action)

	action_completed.emit(completed_action)

	current_action = null
