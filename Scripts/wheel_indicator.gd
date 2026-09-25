extends TextureRect

const LEFT_COLOR := Color(0.0, 1.0, 0.0)
const RIGHT_COLOR := Color(1.0, 0.0, 0.0)
const WHEEL_TINT_RAMP_SHARPNESS := 1.3
## Each open wheel hole removes one of wheel.png's handles.
const HANDLES := 8
# the handles stick out past the rim, a third of the way out, every 45 degrees from -155
const TINT_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int missing = 0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 from_centre = UV - 0.5;
	int handle = (int(round((degrees(atan(from_centre.y, from_centre.x)) + 155.0) / 45.0)) + 8) % 8;
	bool gone = length(from_centre) > 1.0 / 3.0 && ((missing >> handle) & 1) == 1;
	COLOR = vec4(tint.rgb, gone ? 0.0 : tex.a * tint.a);
}
"""

var tint_material: ShaderMaterial
var base_rotation := 0.0
## Open wheel hole -> the handle it took off.
var _handles := {}


func _ready() -> void:

	base_rotation = rotation
	pivot_offset = size / 2.0
	var shader := Shader.new()
	shader.code = TINT_SHADER_CODE
	tint_material = ShaderMaterial.new()
	tint_material.shader = shader
	material = tint_material
	_process(0.0)


func _process(_delta: float) -> void:

	var ship = GlobalShipRegistry.get_player_ship_from_tree(get_tree())

	if ship == null:
		rotation = base_rotation
		tint_material.set_shader_parameter("tint", Color.BLACK)
		update_handles([])
		return

	update_handles(ship.action_points.wheel_holes)

	var wheel_rotation = clamp(
		ship.movement_controller.wheel_rotation,
		-ShipMovementController.MAX_WHEEL_TURN,
		ShipMovementController.MAX_WHEEL_TURN
	)
	var turn = wheel_rotation / ShipMovementController.MAX_WHEEL_TURN
	rotation = base_rotation + wheel_rotation
	tint_material.set_shader_parameter("tint", Color.BLACK.lerp(
		LEFT_COLOR if turn < 0.0 else RIGHT_COLOR,
		pow(absf(turn), 1.0 / WHEEL_TINT_RAMP_SHARPNESS)
	))


func update_handles(holes: Array) -> void:

	for hole in _handles.keys():
		if hole not in holes or hole.grade == 0:
			_handles.erase(hole)

	for hole in holes:
		if hole.grade > 0 and not _handles.has(hole):
			_handles[hole] = range(HANDLES).filter(func(i): return i not in _handles.values()).pick_random()

	tint_material.set_shader_parameter("missing", _handles.values().reduce(func(mask, i): return mask | 1 << i, 0))
