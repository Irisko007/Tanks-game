shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

uniform vec4 albedo : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float emission_strength : hint_range(0.0, 10.0) = 8.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;
uniform float pulse_intensity : hint_range(0.0, 2.0) = 0.5;

void fragment() {
    // Pulsing neon effect
    float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    vec3 base_color = albedo.rgb;
    
    // Create gradient from cyan to magenta
    vec3 neon_gradient = mix(vec3(0.0, 1.0, 1.0), vec3(1.0, 0.0, 1.0), UV.x);
    
    // Add pulse to emission
    float final_emission = emission_strength * (1.0 + pulse * pulse_intensity);
    
    // Fresnel-like edge glow
    float fresnel = dot(NORMAL, VIEW);
    fresnel = pow(1.0 - abs(fresnel), 3.0);
    
    vec3 final_color = neon_gradient * final_emission + base_color * fresnel;
    
    COLOR = vec4(final_color, albedo.a);
}
