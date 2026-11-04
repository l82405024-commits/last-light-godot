shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette_strength = 0.62;
uniform float grain_strength = 0.045;
uniform float aberration = 0.0022;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - vec2(0.5);
	float ca = dot(d, d) * aberration;
	vec3 col;
	col.r = texture(screen_tex, uv + d * ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - d * ca).b;

	float vig = smoothstep(0.32, 0.92, length(d) * 1.32);
	col *= 1.0 - vig * vignette_strength;

	float n = hash21(uv * vec2(1920.0, 1080.0) + fract(TIME) * 137.0) - 0.5;
	col += n * grain_strength;

	col = pow(max(col, vec3(0.0)), vec3(1.02));
	col.rgb = mix(col.rgb, col.rgb * vec3(0.94, 1.0, 1.06), 0.35);

	COLOR = vec4(col, 1.0);
}
