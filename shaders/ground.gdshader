shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 asphalt_a : source_color = vec3(0.055, 0.058, 0.062);
uniform vec3 asphalt_b : source_color = vec3(0.115, 0.112, 0.104);
uniform vec3 moss_color : source_color = vec3(0.1, 0.155, 0.07);
uniform float puddle_amount = 1.0;
uniform float seed = 0.0;

varying vec3 world_pos;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.11 + vec2(3.7, 9.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;

	float grain = fbm(p * 1.6 + seed);
	float patches = fbm(p * 0.22 + seed * 2.0);
	vec3 base = mix(asphalt_a, asphalt_b, clamp(grain * 1.25, 0.0, 1.0));
	base *= 0.85 + 0.3 * patches;

	float crack_n = abs(fbm(p * 0.9 + seed * 4.0) - 0.5);
	float cracks = 1.0 - smoothstep(0.0, 0.022, crack_n);
	cracks *= smoothstep(0.35, 0.55, fbm(p * 0.4 + seed));
	base *= 1.0 - cracks * 0.55;

	float pn = fbm(p * 0.34 + seed * 7.0);
	float puddle = smoothstep(0.615, 0.685, pn) * puddle_amount;
	puddle *= smoothstep(0.0, 2.0, world_pos.y + 1.0);
	base = mix(base, base * 0.32 + vec3(0.008, 0.012, 0.016), puddle);

	float mn = fbm(p * 0.7 + vec2(seed * 8.0, 0.0));
	float moss = smoothstep(0.56, 0.82, mn) * (1.0 - puddle);
	base = mix(base, moss_color * (0.7 + 0.5 * grain), moss * 0.85);

	ALBEDO = base;
	ROUGHNESS = mix(0.9, 0.035, puddle);
	METALLIC = 0.0;
	SPECULAR = mix(0.35, 0.75, puddle);
}
