shader_type sky;
render_mode use_debanding;

uniform vec3 top_color : source_color = vec3(0.018, 0.055, 0.075);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.34, 0.17);
uniform vec3 ground_color : source_color = vec3(0.02, 0.028, 0.032);
uniform vec3 sun_color : source_color = vec3(1.0, 0.62, 0.32);
uniform vec3 cloud_dark : source_color = vec3(0.035, 0.06, 0.075);
uniform vec3 cloud_light : source_color = vec3(0.55, 0.28, 0.16);
uniform float cloud_coverage = 0.52;
uniform float cloud_speed = 0.006;

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
		p = p * 2.03 + vec2(13.7, 7.3);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;

	vec3 col = mix(horizon_color, top_color, smoothstep(-0.02, 0.55, h));
	col = mix(ground_color, col, smoothstep(-0.16, 0.01, h));

	float sun_dot = max(dot(dir, LIGHT0_DIRECTION), 0.0);
	col += sun_color * pow(sun_dot, 220.0) * 6.0;
	col += sun_color * pow(sun_dot, 9.0) * 0.35;

	if (h > 0.005) {
		vec2 cuv = dir.xz / (h + 0.22);
		float drift = TIME * cloud_speed;
		float base = fbm(cuv * 0.75 + vec2(drift, drift * 0.35));
		float detail = fbm(cuv * 2.2 - vec2(drift * 2.0, 0.0));
		float mass = base * 0.75 + detail * 0.25;
		float cover = smoothstep(cloud_coverage, cloud_coverage + 0.28, mass);
		float horizon_fade = smoothstep(0.0, 0.16, h);
		vec3 cloud = mix(cloud_dark, cloud_light, pow(sun_dot, 3.0) * 0.9 + 0.1);
		cloud *= 0.75 + 0.5 * detail;
		col = mix(col, cloud, cover * horizon_fade * 0.92);

		float glow = pow(sun_dot, 4.0) * (1.0 - cover * 0.6);
		col += sun_color * glow * 0.18;
	}

	COLOR = col;
}
