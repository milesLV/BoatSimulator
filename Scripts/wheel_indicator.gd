extends TextureRect

const LEFT_COLOR := Color(0.0, 1.0, 0.0)
const RIGHT_COLOR := Color(1.0, 0.0, 0.0)
const WHEEL_TINT_RAMP_SHARPNESS := 1.3
const TINT_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tint.rgb, tex.a * tint.a);
}
"""

var tint_material: ShaderMaterial
var base_rotation := 0.0


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

	if ship == null or ship.movement_controller == null:
		rotation = base_rotation
		set_wheel_color(Color.BLACK)
		return

	var wheel_rotation = clamp(
		ship.movement_controller.wheel_rotation,
		-ShipMovementController.MAX_WHEEL_TURN,
		ShipMovementController.MAX_WHEEL_TURN
	)
	var turn = wheel_rotation / ShipMovementController.MAX_WHEEL_TURN
	rotation = base_rotation + wheel_rotation
	set_wheel_color(Color.BLACK.lerp(
		LEFT_COLOR if turn < 0.0 else RIGHT_COLOR,
		pow(absf(turn), 1.0 / WHEEL_TINT_RAMP_SHARPNESS)
	))


func set_wheel_color(color: Color) -> void:

	if tint_material != null:
		tint_material.set_shader_parameter("tint", color)
