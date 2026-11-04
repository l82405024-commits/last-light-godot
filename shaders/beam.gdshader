shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 beam_color : source_color = vec4(0.35, 0.9, 1.0, 1.0);
uniform float intensity = 1.0;

void fragment() {
	float fade = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.4);
	float edge = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);
	ALBEDO = beam_color.rgb;
	EMISSION = beam_color.rgb * 2.2 * intensity;
	ALPHA = fade * edge * 0.28 * intensity;
}
