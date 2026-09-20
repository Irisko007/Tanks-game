shader_type spatial;
render_mode unshaded, world_vertex_coords;

uniform vec4 color : source_color = vec4(1.0, 0.0, 1.0, 1.0);
uniform float speed : hint_range(0.1, 5.0) = 1.0;
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;

varying float v_alpha;
varying vec3 v_world_pos;

void vertex() {
    v_world_pos = (world_matrix * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float time = TIME * speed;
    vec3 view_dir = normalize(camera_position - v_world_pos);
    float fresnel = pow(1.0 - abs(dot(view_dir, NORMAL)), 3.0);
    
    float pulse = sin(time * 3.0) * 0.5 + 0.5;
    vec3 neon_color = color.rgb * (1.0 + pulse * glow_intensity);
    
    float alpha = color.a * (0.7 + fresnel * 0.3);
    ALPHA = alpha;
    EMISSION = neon_color * glow_intensity;
}
