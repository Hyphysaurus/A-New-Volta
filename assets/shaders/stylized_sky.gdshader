shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.35, 0.64, 0.89);
uniform vec3 sky_horizon_color : source_color = vec3(0.68, 0.84, 0.95);
uniform float horizon_blur : hint_range(0.0, 1.0) = 0.05;

uniform sampler2D cloud_texture;
uniform vec2 cloud_direction = vec2(0.5, 0.0);
uniform float cloud_speed = 0.01;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_smoothness : hint_range(0.0, 1.0) = 0.1;
uniform vec3 cloud_color : source_color = vec3(1.0);

void sky() {
    float col = clamp(EYEDIR.y / horizon_blur, 0.0, 1.0);
    vec3 final_sky = mix(sky_horizon_color, sky_top_color, col);
    
    // Clouds - projected onto a sphere technically, but simplified here
    if (EYEDIR.y > 0.0) {
        vec2 cloud_uv = (EYEDIR.xz / EYEDIR.y) * 0.5 + TIME * cloud_speed * cloud_direction;
        float cloud_noise = texture(cloud_texture, cloud_uv).r;
        float cloud_alpha = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + cloud_smoothness, cloud_noise);
        final_sky = mix(final_sky, cloud_color, cloud_alpha);
    }
    
    COLOR = final_sky;
}
