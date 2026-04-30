shader_type canvas_item;
render_mode unshaded;

uniform float cone_angle: hint_range(0.1, 360.0) = 90;
uniform float start_angle: hint_range(0.0, 360.0) = 0;
uniform float fade_intensity: hint_range(0.0, 4.0) = 0.0;
uniform float circle_radius: hint_range(0.0, 1.0) = 0.5;
uniform float inner_circle_alpha: hint_range(0.0, 1.0) = 0.8;
uniform float outline_thickness: hint_range(0.0, 0.1) = 0.015;

uniform vec4 color_a: source_color = vec4(0.6, 0.06, 0.06, 0.5);
uniform vec4 color_b: source_color = vec4(0.5, 0.0, 0.025, 0.25);
uniform int color_steps = 3;

uniform float cone_scale = 1.0;

void fragment() {
    vec2 uv = (UV - vec2(0.5)) * cone_scale + vec2(0.5);
    vec2 centered_uv = uv - vec2(0.5);
    float angle = atan(centered_uv.y, centered_uv.x);
    float radius = length(centered_uv);

    float cone_radians = radians(cone_angle / 2.0);
    float start_radians = radians(start_angle);

    angle -= start_radians;
    angle = mod(angle + PI, 2.0 * PI) - PI;

    float within_cone = step(abs(angle), cone_radians);

    float scaled_circle_radius = circle_radius * cone_scale;
    float within_circle = step(radius, scaled_circle_radius);

    float fade = smoothstep(1.0, 0.0, (radius / cone_scale) * fade_intensity);

    float outline = step(scaled_circle_radius - outline_thickness, radius)
                  - step(scaled_circle_radius, radius);

    float angle_outline = 0.0;
    const float epsilon = 0.0001;

    if (abs(cone_angle) > epsilon && abs(cone_angle - 360.0) > epsilon) {
        angle_outline = step(cone_radians - radians(outline_thickness * 180.0 / 3.14159), abs(angle))
                      - step(cone_radians, abs(angle));
    }

    float combined_outline = max(outline, angle_outline);

    // --- NEW: stepped gradient ---
    float t = clamp(radius / scaled_circle_radius, 0.0, 1.0);

    float steps = float(max(color_steps, 1));
    float stepped_t = floor(t * steps) / steps;

    vec3 gradient_color = mix(color_a.rgb, color_b.rgb, stepped_t);

    // Base color
    float gradient_alpha = mix(color_a.a, color_b.a, stepped_t);

	float final_alpha = gradient_alpha * inner_circle_alpha * fade * within_cone * within_circle;

	vec4 color = vec4(gradient_color, final_alpha);
	vec4 outline_color = vec4(gradient_color, combined_outline * final_alpha);

    COLOR = mix(color, outline_color, outline_color.a);
}