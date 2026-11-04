shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float wind_strength = 1.0;
uniform vec3 base_color : source_color = vec3(0.09, 0.13, 0.055);
uniform vec3 tip_color : source_color = vec3(0.28, 0.34, 0.14);

void vertex() {
	float sway = sin(TIME * 1.7 + VERTEX.x * 1.3 + VERTEX.z * 0.9);
	sway += 0.35 * sin(TIME * 3.1 + VERTEX.z * 2.7);
	VERTEX.x += sway * 0.07 * UV.y * wind_strength;
	VERTEX.z += sway * 0.045 * UV.y * wind_strength;
}

void fragment() {
	float width = 1.0 - UV.y;
	if (abs(UV.x - 0.5) * 2.0 > width) {
		discard;
	}
	vec3 col = mix(base_color, tip_color, UV.y * UV.y);
	col *= 0.8 + 0.35 * COLOR.r;
	ALBEDO = col;
	ROUGHNESS = 0.92;
	BACKLIGHT = vec3(0.22, 0.3, 0.12) * UV.y;
}
