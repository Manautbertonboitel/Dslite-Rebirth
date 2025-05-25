shader_type spatial;

uniform float wave_height = 0.002;
uniform float halo_reaction = 10.0;
uniform float time = 1.0;
uniform sampler2D example_texture : source_color;
uniform float rotation_speed = 1.0;


void vertex() {
	VERTEX.z += sin(TIME * time + VERTEX.x * halo_reaction) * wave_height;
	
	float angle = rotation_speed * TIME * time;
	
	mat4 rotation_matrix = mat4(
		vec4(cos(angle), -sin(angle), 0.0, 0.0),
		vec4(sin(angle), cos(angle), 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0),   
		vec4(0.0, 0.0, 0.0, 1.0)
		);
		
	VERTEX = (rotation_matrix * vec4(VERTEX, 1.0)).xyz;
	
}

void fragment() {
	vec3 color;
	color.r = 3.0;
	color.g = 6.0;
	color.b = 0.0;
	
	ALBEDO = color;
	ROUGHNESS = 0.1;
	METALLIC = 1.0;
	ALPHA = 0.5;
	EMISSION = color;
	
	
}