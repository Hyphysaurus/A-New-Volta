shader_type spatial;

// Cel-shaded water colors (Windwaker-inspired)
uniform vec4 water_shallow : source_color = vec4(0.4, 0.8, 0.9, 1.0);
uniform vec4 water_mid : source_color = vec4(0.2, 0.6, 0.8, 1.0);
uniform vec4 water_deep : source_color = vec4(0.05, 0.3, 0.6, 1.0);
uniform vec4 water_very_deep : source_color = vec4(0.02, 0.15, 0.4, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform sampler2D texture_normal;
uniform vec2 wave_direction = vec2(2.0, 0.0);
uniform float wave_speed = 0.1;

uniform float noise_scale = 10.0;
uniform float height_scale = 0.15;

// Cel-shading parameters
uniform float depth_band_1 : hint_range(0.0, 10.0) = 1.0;
uniform float depth_band_2 : hint_range(0.0, 20.0) = 4.0;
uniform float depth_band_3 : hint_range(0.0, 50.0) = 12.0;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float foam_distance : hint_range(0.0, 5.0) = 1.5;
uniform float foam_cutoff : hint_range(0.0, 1.0) = 0.3;
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 1.0);

float fresnel(float amount, vec3 normal, vec3 view)
{
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0)), amount);
}

void vertex() {
    float height = texture(texture_normal, VERTEX.xz / noise_scale + TIME * wave_speed).r;
    VERTEX.y += height * height_scale;
}

float linearize_depth(float d, mat4 proj_matrix) {
    float z_near = 0.05; // Adjust based on camera
    float z_far = 4000.0; // Adjust based on camera
    return proj_matrix[3][2] / (d + proj_matrix[2][2]);
}

void fragment() {
    // Calculate depth
    float depth_texture_y = texture(depth_texture, SCREEN_UV).r;
    float depth = PROJECTION_MATRIX[3][2] / (depth_texture_y + PROJECTION_MATRIX[2][2]);
    depth = depth + VERTEX.z;
    
    // Cel-shaded depth bands (hard steps for cartoon look)
    vec3 water_color;
    if (depth < depth_band_1) {
        water_color = water_shallow.rgb;
    } else if (depth < depth_band_2) {
        water_color = water_mid.rgb;
    } else if (depth < depth_band_3) {
        water_color = water_deep.rgb;
    } else {
        water_color = water_very_deep.rgb;
    }
    
    // Foam/Edge detection (enhanced for visibility)
    float z_pos = linearize_depth(texture(depth_texture, SCREEN_UV).x, PROJECTION_MATRIX);
    float z_pos_vertex = linearize_depth(FRAGCOORD.z, PROJECTION_MATRIX);
    float diff = z_pos - z_pos_vertex;
    
    // Hard-edged foam (cel-shaded style)
    float foam_factor = step(diff, foam_distance);
    foam_factor *= step(foam_cutoff, 1.0 - diff / foam_distance);
    
    // Mix foam with water color
    vec3 final_color = mix(water_color, foam_color, foam_factor);
    
    ALBEDO = final_color;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    SPECULAR = 0.5;
}
