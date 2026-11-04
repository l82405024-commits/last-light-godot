shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 wave_color : source_color = vec4(0.32, 0.85, 1.0, 1.0);
uniform float alpha = 1.0;
uniform float rings = 5.0;

void fragment() {
	float fres = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	fres = pow(clamp(fres, 0.0, 1.0), 1.6);
	float band = 0.65 + 0.35 * sin(UV.y * rings * 6.2831 - TIME * 4.0);
	ALBEDO = wave_color.rgb;
	EMISSION = wave_color.rgb * 2.4 * band;
	ALPHA = clamp(fres * 0.9 + 0.02, 0.0, 1.0) * alpha * band;
}
