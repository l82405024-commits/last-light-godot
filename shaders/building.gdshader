shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 wall_color : source_color = vec3(0.33, 0.335, 0.31);
uniform vec3 wall_color_b : source_color = vec3(0.19, 0.2, 0.195);
uniform vec3 moss_color : source_color = vec3(0.13, 0.19, 0.09);
uniform vec3 lit_warm : source_color = vec3(1.0, 0.58, 0.24);
uniform vec3 lit_cold : source_color = vec3(0.45, 0.78, 1.0);
uniform vec2 window_size = vec2(2.3, 3.1);
uniform float window_margin_x = 0.2;
uniform float window_margin_y = 0.26;
uniform float power_on = 0.0;
uniform float moss_amount = 1.0;
uniform float seed = 0.0;
uniform float ruin = 0.0;
uniform float windows_enabled = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

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
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.07 + vec2(7.1, 3.3);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(normalize(world_normal));
	vec2 uv;
	float face_id;
	if (n.y > 0.5) {
		uv = world_pos.xz;
		face_id = 3.0;
	} else if (n.x > n.z) {
		uv = world_pos.zy;
		face_id = 1.0;
	} else {
		uv = world_pos.xy;
		face_id = 2.0;
	}

	float grime = fbm(uv * 0.62 + seed) * 0.65 + fbm(uv * 3.3 - seed * 2.0) * 0.35;
	vec3 base = mix(wall_color, wall_color_b, clamp(grime * 1.35, 0.0, 1.0));

	vec2 streak_uv = vec2(uv.x * 1.7, uv.y * 0.16);
	float streaks = fbm(streak_uv + seed * 3.0);
	base *= 1.0 - smoothstep(0.5, 0.85, streaks) * 0.22;

	float floor_line = 1.0 - smoothstep(0.0, 0.055, abs(fract(world_pos.y / window_size.y) - 0.5));
	base *= 1.0 - floor_line * 0.28;

	float moss_n = fbm(uv * 1.15 + vec2(seed * 4.0, -seed * 2.0));
	float moss = smoothstep(0.52, 0.86, moss_n) * (1.0 - smoothstep(0.0, 3.6, world_pos.y));
	moss += smoothstep(0.58, 0.9, moss_n) * smoothstep(0.55, 0.9, n.y);
	moss *= moss_amount;
	base = mix(base, moss_color, clamp(moss, 0.0, 0.82));

	float ruin_grime = smoothstep(0.35, 0.9, fbm(uv * 0.9 + seed * 9.0)) * ruin;
	base *= 1.0 - ruin_grime * 0.35;

	vec3 albedo = base;
	vec3 emission = vec3(0.0);
	float rough = 0.86;
	float metal = 0.0;

	if (n.y < 0.55 && windows_enabled > 0.5) {
		vec2 cell = uv / window_size;
		vec2 id = floor(cell);
		vec2 f = fract(cell);

		float wx = smoothstep(window_margin_x, window_margin_x + 0.035, f.x) * (1.0 - smoothstep(0.98 - window_margin_x - 0.035, 0.98 - window_margin_x, f.x));
		float wy = smoothstep(window_margin_y, window_margin_y + 0.035, f.y) * (1.0 - smoothstep(0.96 - window_margin_y - 0.035, 0.96 - window_margin_y, f.y));
		float win = wx * wy;

		float mullion_x = 1.0 - smoothstep(0.0, 0.018, abs(f.x - 0.5));
		float mullion_y = 1.0 - smoothstep(0.0, 0.022, abs(f.y - 0.5));
		float frame = clamp(mullion_x + mullion_y, 0.0, 1.0) * win;

		float broken = step(0.87, hash21(id + vec2(seed * 5.0, face_id * 3.0)));

		albedo = mix(albedo, vec3(0.012, 0.017, 0.022), win * (1.0 - broken * 0.55));
		rough = mix(rough, 0.16, win * (1.0 - broken * 0.7));
		metal = mix(metal, 0.45, win * (1.0 - broken * 0.8));

		albedo = mix(albedo, vec3(0.055, 0.055, 0.05), frame * 0.8);
		rough = mix(rough, 0.7, frame);
		metal = mix(metal, 0.1, frame);

		float lit_roll = hash21(id + vec2(seed * 11.0, face_id * 7.0));
		float threshold = mix(0.93, 0.52, power_on);
		float lit = step(threshold, lit_roll) * win * (1.0 - broken);

		float tint = hash21(id + vec2(5.0, face_id * 9.0));
		vec3 lit_color = mix(lit_warm, lit_cold, step(0.72, tint));
		float bright = mix(0.45, 2.6, power_on) * (0.55 + 0.75 * hash21(id + vec2(seed, 3.0)));
		float flicker = 1.0;
		if (tint > 0.94) {
			flicker = 0.55 + 0.45 * sin(TIME * 11.0 + lit_roll * 40.0);
		}
		emission += lit_color * lit * bright * flicker;
	}

	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emission;
}
