shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 neon_color : source_color = vec4(0.35, 0.9, 1.0, 1.0);
uniform float power = 0.0;
uniform float seed = 0.0;
uniform float scanlines = 1.0;

void fragment() {
	float t = TIME;
	float flick = 0.88 + 0.12 * sin(t * 13.0 + seed) * sin(t * 2.3 + seed * 1.7);
	float on = smoothstep(0.35, 0.85, power);
	float lines = 1.0 - scanlines * 0.16 * (0.5 + 0.5 * sin(UV.y * 240.0));
	vec3 col = neon_color.rgb * flick * lines;
	ALBEDO = col * mix(0.18, 1.0, on);
	EMISSION = col * mix(0.35, 2.8, on);
	ALPHA = mix(0.3, 1.0, on) * flick;
}
