extends ActionDefinition
class_name TriggerShipStateAction

var target_object: Object
var method_name: StringName
var method_args: Array = []


func _init(
	new_action_id: String,
	new_target_object: Object,
	new_method_name: StringName,
	new_method_args := [],
	new_action_point: ShipActionPoint = null
) -> void:

	action_id = new_action_id
	target_object = new_target_object
	method_name = new_method_name
	method_args = new_method_args
	action_point = new_action_point
	base_duration = 0.0
	progress_policy = ProgressPolicy.ONE_SHOT

	if action_point != null:
		action_location = String(action_point.name)


func on_start(_actor, _instance) -> void:

	if target_object == null:
		push_error(
			"%s has no target object."
			% action_id
		)
		return

	if not target_object.has_method(
		method_name
	):
		push_error(
			"%s target cannot handle %s."
			% [
				action_id,
				method_name
			]
		)
		return

	target_object.callv(
		method_name,
		method_args
	)
