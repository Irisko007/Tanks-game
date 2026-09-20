shader_type canvas_item;

uniform vec4 color : source_color = vec4(0.5, 0.0, 1.0, 1.0);
uniform float speed : hint_range(0.1, 5.0) = 1.0;
uniform float star_size : hint_range(0.1, 5.0) = 2.0;
uniform int star_count : hint_range(10, 500) = 100;

void fragment() {
    vec2 uv = UV;
    vec4 base = texture(SCREEN_TEXTURE, uv);
    
    float time = TIME * speed;
    vec3 final_color = base.rgb;
    
    for (int i = 0; i < 20; i++) {
        float seed = float(i) * 127.1;
        vec2 star_pos = vec2(
            fract(sin(seed) * 43758.5453) * 2.0 - 1.0,
            fract(cos(seed * 1.3) * 43758.5453)
        );
        
        star_pos.y -= time * 0.1;
        if (star_pos.y < -1.0) {
            star_pos.y += 2.0;
        }
        
        float dist = distance(uv * 2.0 - 1.0, star_pos);
        float star = smoothcast(star_size * 0.01, 0.0, dist);
        
        vec3 star_color = mix(
            vec3(1.0, 0.0, 1.0),
            vec3(0.0, 1.0, 1.0),
            sin(time + float(i)) * 0.5 + 0.5
        );
        
        final_color += star_color * star * 0.8;
    }
    
    COLOR = vec4(final_color, 1.0);
}
