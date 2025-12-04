shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 10.0) = 3.0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5, 0.5);

	// Distance from center
	float dist = distance(uv, center);

	// Swirl angle based on distance and progress
	float angle = progress * strength * (1.0 - dist);

	// Rotate UV
	vec2 offset = uv - center;
	float cos_angle = cos(angle);
	float sin_angle = sin(angle);
	vec2 rotated = vec2(
		offset.x * cos_angle - offset.y * sin_angle,
		offset.x * sin_angle + offset.y * cos_angle
	) + center;

	// Sample texture with distortion
	vec4 color = texture(screen_texture, rotated);

	// Fade to black
	color.rgb *= (1.0 - progress);

	COLOR = color;
}
