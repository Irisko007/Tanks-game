shader_type canvas_item;

uniform vec4 neon_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_amount : hint_range(0.0, 2.0) = 0.3;

void fragment() {
    vec4 base_color = texture(TEXTURE, UV);
    
    // Pulsing effect
    float pulse = sin(TIME * pulse_speed) * pulse_amount + 1.0;
    
    // Neon glow
    vec3 glow_color = neon_color.rgb * glow_intensity * pulse;
    
    // Mix with gradient
    vec3 gradient = mix(vec3(1.0, 0.0, 1.0), vec3(0.0, 1.0, 1.0), UV.x);
    
    COLOR = base_color * vec4(glow_color * gradient, neon_color.a);
}
