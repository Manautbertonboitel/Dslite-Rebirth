shader_type canvas_item;

uniform float time;
uniform float speed = 1.5;
uniform float thickness = 0.05;
uniform float intensity = 2.0;

void fragment() {
    vec2 uv = UV - 0.5;
    
    float t = TIME * speed;

    // Expansion
    float dist = length(uv);
    float wave = smoothstep(t, t - 0.2, dist);

    // Croix (axes)
    float cross_x = smoothstep(thickness, 0.0, abs(uv.x));
    float cross_y = smoothstep(thickness, 0.0, abs(uv.y));
    
    float cross = max(cross_x, cross_y);

    // Combinaison
    float glow = cross * wave;
	
	float ring = smoothstep(t, t - 0.1, dist);
	glow += ring * 0.5;

    COLOR = vec4(vec3(glow * intensity), glow);
}