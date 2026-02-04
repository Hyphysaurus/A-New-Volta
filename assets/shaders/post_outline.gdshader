shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_nearest;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float depth_threshold = 0.05;
uniform float normal_threshold = 0.5;
uniform float outline_thickness = 1.0;

void vertex() {
	POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
    float depth = texture(depth_texture, SCREEN_UV).r;
    vec3 normal = texture(normal_texture, SCREEN_UV).rgb * 2.0 - 1.0;
    
    vec2 tex_size = vec2(textureSize(screen_texture, 0));
    vec2 pixel_size = outline_thickness / tex_size;
    
    float depth_diff = 0.0;
    float normal_diff = 0.0;
    
    float d = depth;
    float d_u = texture(depth_texture, SCREEN_UV + vec2(0.0, -pixel_size.y)).r;
    float d_d = texture(depth_texture, SCREEN_UV + vec2(0.0, pixel_size.y)).r;
    float d_l = texture(depth_texture, SCREEN_UV + vec2(-pixel_size.x, 0.0)).r;
    float d_r = texture(depth_texture, SCREEN_UV + vec2(pixel_size.x, 0.0)).r;
    
    depth_diff += abs(d - d_u);
    depth_diff += abs(d - d_d);
    depth_diff += abs(d - d_l);
    depth_diff += abs(d - d_r);

    vec3 n = normal;
    vec3 n_u = texture(normal_texture, SCREEN_UV + vec2(0.0, -pixel_size.y)).rgb * 2.0 - 1.0;
    vec3 n_d = texture(normal_texture, SCREEN_UV + vec2(0.0, pixel_size.y)).rgb * 2.0 - 1.0;
    vec3 n_l = texture(normal_texture, SCREEN_UV + vec2(-pixel_size.x, 0.0)).rgb * 2.0 - 1.0;
    vec3 n_r = texture(normal_texture, SCREEN_UV + vec2(pixel_size.x, 0.0)).rgb * 2.0 - 1.0;
    
    normal_diff += distance(n, n_u);
    normal_diff += distance(n, n_d);
    normal_diff += distance(n, n_l);
    normal_diff += distance(n, n_r);
    
    float outline = 0.0;
    if (depth_diff > depth_threshold || normal_diff > normal_threshold) {
        outline = 1.0;
    }
    
    vec3 color = texture(screen_texture, SCREEN_UV).rgb;
    ALBEDO = mix(color, outline_color.rgb, outline * outline_color.a);
}
