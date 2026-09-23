shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 aura_color : source_color = vec4(1.0, 0.65, 0.03, 0.75);
uniform float strength = 0.7;
uniform float time_offset = 0.0;

void vertex() {
    float flicker = sin(TIME * 8.0 + VERTEX.y * 5.0 + time_offset) * 0.07;
    VERTEX.xz *= 1.0 + flicker;
    VERTEX.y += sin(TIME * 5.0 + VERTEX.x * 4.0) * 0.045;
}
void fragment() {
    float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.7);
    float wave = 0.72 + 0.28 * sin(TIME * 11.0 + UV.y * 25.0);
    ALBEDO = aura_color.rgb;
    EMISSION = aura_color.rgb * (1.5 + strength * 2.0);
    ALPHA = clamp(edge * wave * strength * aura_color.a, 0.0, 0.86);
}

