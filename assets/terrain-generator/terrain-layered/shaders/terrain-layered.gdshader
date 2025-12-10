shader_type spatial;


group_uniforms terrain_layers;

uniform sampler2D terrain_textures[8] :source_color ; 
uniform int terrain_textures_size = 0;
uniform bool terrain_textures_rotate = false;
uniform float terrain_textures_tile_scale[8] ;

uniform sampler2D terrain_textures_normals[8] : source_color ; 

uniform sampler2D terrain_layers_weights[8] : source_color ; 
uniform int terrain_layers_weights_size = 0;

uniform int terrain_layers_enabled = 0;

uniform vec2 terrain_layers_offset = vec2(0.0, 0.0);

group_uniforms terrain_cliffs;
uniform bool cliff_enabled = false;
uniform sampler2D cliff_texture :source_color ; 
uniform sampler2D cliff_normal : source_color ; 
uniform vec3 cliff_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float cliff_texture_scale = 1.0f;
uniform sampler2D cliff_layer_weights : source_color ; 


group_uniforms terrain_stain;
uniform sampler2D stain_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 stain_texture_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float stain_texture_scale = 1.0f;
uniform float stain_texture_strength : hint_range(0.0, 1.0, 0.01) = 0.0f;


group_uniforms general_settings;
uniform bool make_flat = false;
uniform float normal_strength : hint_range(0.01, 6.0, 0.01) = 1.0;


//	Varying variables
varying vec3 v_view_pos;	//	used to calculate normal based on displaced vertex




vec2 rotateUV(vec2 uv, vec2 pivot, float rotation)
{
	mat2 rotation_matrix=mat2(	vec2(sin(rotation),-cos(rotation)),
								vec2(cos(rotation),sin(rotation))
								);
    uv -= pivot;
    uv= uv*rotation_matrix;
    uv += pivot;
    return uv;
}

float rand(vec2 input) {
	return fract(sin(dot(input.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

vec2 get_uv_untiled(vec2 uv) {
	vec2 unique_val = floor(uv) ;
	float rotation = (rand(unique_val) * 2.0 - 1.0) * 3.14;
	return rotateUV(uv, vec2(0.5), rotation);
}

//	calculate data for layer
void calculate_data(vec2 position, float texture_scale, bool rotate_texture, sampler2D tex, sampler2D nor, inout vec2 uv, inout vec3 color, inout vec3 normal) {

	uv = position / texture_scale;
	if (rotate_texture)
		uv = get_uv_untiled(uv);

	color = texture(tex, uv).rgb ;
	normal = texture(nor, uv).rgb;

}

void vertex() {
	// get the view pos for the low poly normals
	v_view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 0.0)).xyz;
}


void fragment() {

	//	Get the world position
	vec3 pixel_world_position = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

	vec3 color = vec3(1.0);
	float layer_weight = 0.0;

	for (int l = 0; l < terrain_layers_weights_size; l++) {

		vec2 layer_uv;
		vec3 layer_color;
		vec3 layer_normal;
		
		calculate_data(
			pixel_world_position.xz, 
			terrain_textures_tile_scale[l], 
			terrain_textures_rotate, 
			terrain_textures[l], 
			terrain_textures_normals[l], 
			layer_uv, 
			layer_color, 
			layer_normal) ;

		vec3 color2 = texture(terrain_textures[l], UV * terrain_textures_tile_scale[l]).rgb;
		float layer_weight2 = texture(terrain_layers_weights[l], UV + terrain_layers_offset).r;
		
		color = mix(layer_color, color, layer_weight);
		layer_weight += layer_weight2;
		
	}
	color = clamp(color, 0.0, 1.0);
		
	//	Stain
	vec2 stain_uv = pixel_world_position.xz / stain_texture_scale;
	stain_uv = get_uv_untiled(stain_uv);

	vec3 stain_color = texture(stain_texture, stain_uv).r * stain_texture_color;

	float stain_blend = stain_texture_strength;
	stain_blend = pow(stain_texture_strength, 0.250);
	stain_blend = clamp(stain_blend, 0.0, 1.0);
	
	color = mix(color, color * stain_color, stain_blend) ;

	vec3 normal_value = NORMAL_MAP;

	if (cliff_enabled) {
		vec3 cliff_texture_color = texture(cliff_texture, UV * cliff_texture_scale).rgb;
		float cliff_weight = texture(cliff_layer_weights, UV + terrain_layers_offset).r;
		color = mix(color, cliff_texture_color * cliff_color, cliff_weight);
	
		vec3 cliff_normal_value = texture(cliff_normal, UV * cliff_texture_scale).rgb ;
		normal_value = mix(normal_value, cliff_normal_value, cliff_weight);
	}

	ALBEDO = color;

	if (make_flat) {
		//	Normal calculation based on vertex displacement
		vec3 xTangent = dFdx( v_view_pos );
	    vec3 yTangent = dFdy( v_view_pos );
		vec3 normal_flat = -normalize( cross( xTangent, yTangent ) );

		NORMAL = normal_flat;
	} else {
		NORMAL_MAP = normal_value;
		NORMAL_MAP_DEPTH = -normal_strength;
	}

}

