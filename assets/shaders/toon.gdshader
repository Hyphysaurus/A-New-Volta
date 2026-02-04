shader_type spatial;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float rim_width : hint_range(0.0, 1.0) = 0.2;
uniform vec4 rim_color : source_color = vec4(1.0);
uniform float specular_intensity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    ALBEDO = albedo.rgb;
}

void light() {
    // Diffuse lighting with hard step (cel shading)
    float NdotL = dot(NORMAL, LIGHT);
    float light_intensity = smoothstep(0.0, 0.01, NdotL);
    
    // Specular lighting
    vec3 half_vector = normalize(VIEW + LIGHT);
    float NdotH = dot(NORMAL, half_vector);
    float specular = step(0.9, pow(NdotH, 100.0 * (1.0 - specular_intensity)));
    
    // Rim lighting
    float rim_dot = 1.0 - dot(VIEW, NORMAL);
    float rim = smoothstep(1.0 - rim_width, 1.0 - rim_width + 0.01, rim_dot) * NdotL;
    
    // Combine
    vec3 diffuse = mix(shadow_color.rgb, LIGHT_COLOR, light_intensity);
    DIFFUSE_LIGHT += ALBEDO * diffuse * ATTENUATION;
    SPECULAR_LIGHT += specular * LIGHT_COLOR * ATTENUATION;
    DIFFUSE_LIGHT += rim * rim_color.rgb * light_intensity * ATTENUATION;
}
