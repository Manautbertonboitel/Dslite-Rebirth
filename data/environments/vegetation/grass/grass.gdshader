shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color;
uniform vec3 color2 : source_color;
uniform sampler2D noise_tex;
uniform float noiseScale = 20.0;
group_uniforms wind;
uniform float wind_speed = .1;
uniform float wind_strength = .01;

varying vec3 worldPos;

void vertex() {
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	float offset = TIME * wind_speed;
	float noise = texture(noise_tex, NODE_POSITION_WORLD.xz-offset).r;
	noise -= .5;
	noise *= wind_strength;
	VERTEX.xy += noise * length(VERTEX.y-NODE_POSITION_WORLD.y);
}

void fragment() {
	vec3 noiseLevel = texture(noise_tex, worldPos.xz / noiseScale).rgb;
	ALBEDO = mix(color, color2, UV.y) * mix(color, color2, noiseLevel.r);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
