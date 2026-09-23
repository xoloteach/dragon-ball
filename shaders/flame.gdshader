shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 energy_color : source_color = vec4(1.0, 0.62, 0.06, 0.6);
uniform float strength = 0.65;

void vertex() {
    float waviness = sin(TIME * 8.0 + VERTEX.y * 6.0 + VERTEX.x * 4.0) * 0.10;
    VERTEX.x += waviness * UV.y;
    VERTEX.z += cos(TIME * 7.0 + VERTEX.y * 4.0 + VERTEX.z) * 0.09 * UV.y;
}

void fragment() {
    float taper = pow(1.0 - UV.y, 0.65);
    float flicker = 0.75 + 0.25 * sin(TIME * 12.0 + UV.x * 7.0 + UV.y * 13.0);
    ALBEDO = energy_color.rgb;
    EMISSION = energy_color.rgb * (2.1 + 1.5 * strength);
    ALPHA = clamp(energy_color.a * COLOR.a * taper * flicker * strength, 0.0, 0.67);
}
