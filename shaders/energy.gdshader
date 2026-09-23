shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 energy_color : source_color = vec4(1.0, 0.72, 0.12, 1.0);

void fragment() {
    float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.8);
    float wave = sin(UV.y * 38.0 - TIME * 16.0 + sin(UV.x * 31.0 + TIME * 7.0) * 2.0);
    float crackle = sin(UV.x * 61.0 + UV.y * 43.0 + TIME * 20.0);
    float trace = smoothstep(0.50, 0.96, wave * 0.65 + crackle * 0.35);
    float glow = 0.35 + rim * 1.5 + trace * 0.75;
    ALBEDO = energy_color.rgb * glow;
    EMISSION = energy_color.rgb * (1.0 + rim * 2.8 + trace * 1.8);
    ALPHA = clamp((0.12 + rim * 0.48 + trace * 0.16) * energy_color.a, 0.06, 0.76);
}
