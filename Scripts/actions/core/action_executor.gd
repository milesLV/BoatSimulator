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
		var instance = ActionInstance.new(definition)

		queued_actions.append(instance)
		plan_actions.append(instance)

	if current_action == null:
		_start_next_action()


## A new plan that resumes the current action at the same point keeps its progress.
func replace_plan(definitions: Array) -> void:

	var current = current_action.definition if current_action else null

	for i in definitions.size():
		if current == null or definitions[i].get("point") != current.get("point"):
			break

		if definitions[i].action_id == current.action_id:
			queued_actions.clear()
			plan_actions = plan_actions.slice(0, plan_actions.find(current_action) + 1)
			queue_actions(definitions.slice(i + 1))
			return

		if not definitions[i] is MoveToPointAction:
			break

	cancel_plan()
	queue_actions(definitions)


func has_actions() -> bool:

	return current_action != null or not queued_actions.is_empty()


func cancel_plan() -> bool:

	var had_actions = has_actions()

	if current_action != null:
		if current_action.definition.progress_policy == ActionDefinition.ProgressPolicy.ONE_SHOT:
			current_action.elapsed = 0.0

		current_action.definition.on_interrupt(actor, current_action)
		current_action = null

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

	# on_complete may cancel the plan, so hold on to what finished
	var completed_action = current_action
	completed_action.finished = true
	completed_action.definition.on_complete(actor, completed_action)
	action_completed.emit(completed_action)
	current_action = null
