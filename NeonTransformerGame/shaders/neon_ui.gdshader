shader_type canvas_item;

uniform vec4 neon_color : source_color = vec4(1.0, 0.0, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.1, 5.0) = 2.0;
uniform float glow_strength : hint_range(0.0, 5.0) = 2.0;

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    
    float time = TIME * pulse_speed;
    float pulse = sin(time) * 0.3 + 0.7;
    
    vec3 outline = neon_color.rgb * pulse * glow_strength;
    float edge = 1.0 - smoothstep(0.0, 3.0, length(UV * 2.0 - 1.0));
    
    vec3 final_color = mix(base.rgb, outline, edge * 0.5);
    final_color += outline * edge * glow_strength * 0.3;
    
    COLOR = vec4(final_color, base.a);
}
