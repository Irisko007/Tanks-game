shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, blend_add;

uniform vec4 albedo : source_color = vec4(1.0, 0.8, 1.0, 1.0);
uniform float emission_strength : hint_range(0.0, 10.0) = 5.0;
uniform float star_size : hint_range(0.0, 2.0) = 0.5;
uniform float speed : hint_range(0.0, 10.0) = 2.0;
uniform float trail_length : hint_range(0.0, 5.0) = 3.0;

varying float v_alpha;
varying vec3 v_velocity;

void vertex() {
    // Animate stars falling
    float time = TIME * speed;
    vec3 pos = VERTEX;
    
    // Make stars fall downward
    pos.y -= mod(time + INSTANCE_CUSTOM.x * 10.0, 20.0);
    
    // Add some horizontal drift
    pos.x += sin(time * 0.5 + INSTANCE_CUSTOM.y) * 0.5;
    
    VERTEX = pos;
    
    // Calculate velocity for trail effect
    v_velocity = vec3(0.0, -speed, 0.0);
}

void fragment() {
    vec3 color = albedo.rgb * emission_strength;
    
    // Create star core with glow
    vec2 uv = UV * 2.0 - 1.0;
    float dist = length(uv);
    
    // Star center
    float star = smoothstep(star_size, 0.0, dist);
    
    // Trail effect
    float trail = smoothstep(trail_length, 0.0, dist + dot(uv, normalize(v_velocity.xy)) * 0.5);
    
    v_alpha = max(star, trail * 0.3);
    
    // Neon glow colors
    vec3 neon_color = mix(vec3(1.0, 0.0, 1.0), vec3(0.0, 1.0, 1.0), sin(TIME + UV.x * 10.0));
    
    COLOR = vec4(color * neon_color, v_alpha * albedo.a);
}
