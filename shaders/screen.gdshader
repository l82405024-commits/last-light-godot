shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 screen_color : source_color = vec4(0.35, 0.95, 1.0, 1.0);
uniform float power = 0.0;
uniform float seed = 0.0;

void fragment() {
	float scan = 0.82 + 0.18 * sin(UV.y * 160.0 + TIME * 3.0);
	float flick = 0.92 + 0.08 * sin(TIME * 9.0 + seed);
	float grid = 0.9 + 0.1 * step(0.5, fract(UV.x * 24.0));
	vec3 col = screen_color.rgb * scan * flick * grid;
	float on = mix(0.25, 1.0, power);
	ALBEDO = col * 0.3 * on;
	EMISSION = col * 1.8 * on;
	ROUGHNESS = 0.2;
	METALLIC = 0.4;
}
