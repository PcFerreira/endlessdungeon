shader_type spatial;

uniform vec3 mage_position;
uniform vec2 camera_forward = vec2(0.7071, 0.7071);
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform bool textured = false;
uniform bool use_vertex_color = true;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 pigment = base_color;
	if (textured) {
		pigment *= texture(albedo_tex, UV);
	}
	if (pigment.a < 0.5) {
		discard;
	}
	ALBEDO = pigment.rgb * (use_vertex_color ? COLOR.rgb : vec3(1.0));
	ROUGHNESS = 0.95;
	vec3 offset = world_position - mage_position;
	float forward = dot(offset.xz, camera_forward);
	float side = dot(offset.xz, vec2(camera_forward.y, -camera_forward.x));
	float height = offset.y - forward * 0.7;
	if (forward > 0.21 && abs(side) < 0.60 && height > 0.05 && height < 1.40 && world_position.y > mage_position.y + 0.35) {
		float pattern = mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 4.0);
		if (pattern > 0.0) {
			discard;
		}
	}
}
