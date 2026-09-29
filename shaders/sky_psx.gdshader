shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.34, 0.52, 0.78);
uniform vec3 sky_horizon_color : source_color = vec3(0.72, 0.78, 0.73);
uniform vec3 ground_color : source_color = vec3(0.24, 0.22, 0.16);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_speed : hint_range(0.0, 0.2) = 0.015;
uniform float sun_size : hint_range(1.0, 1024.0) = 350.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * value_noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void sky() {
	vec3 color;

	if (EYEDIR.y >= 0.0) {
		float horizon_mix = pow(clamp(1.0 - EYEDIR.y, 0.0, 1.0), 3.0);
		color = mix(sky_top_color, sky_horizon_color, horizon_mix);

		vec2 uv = EYEDIR.xz / max(EYEDIR.y, 0.05) * 0.3 + vec2(TIME * cloud_speed, 0.0);
		float clouds = fbm(uv);
		clouds = smoothstep(cloud_coverage, cloud_coverage + 0.3, clouds);
		clouds *= smoothstep(0.0, 0.15, EYEDIR.y);
		color = mix(color, cloud_color, clouds * 0.85);
	} else {
		float ground_mix = pow(clamp(-EYEDIR.y, 0.0, 1.0), 0.5);
		color = mix(sky_horizon_color, ground_color, ground_mix);
	}

	if (LIGHT0_ENABLED) {
		float sun_amount = max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0);
		float sun_disc = pow(sun_amount, sun_size);
		float sun_glow = pow(sun_amount, 8.0) * 0.15;
		color += LIGHT0_COLOR * (sun_disc * 3.0 + sun_glow);
	}

	COLOR = color;
}
