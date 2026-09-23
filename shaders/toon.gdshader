shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

uniform vec4 base_color : source_color = vec4(1.0);
uniform float glow = 0.0;

void fragment() {
    ALBEDO = base_color.rgb;
    ROUGHNESS = 1.0;
    EMISSION = base_color.rgb * glow;
}

void light() {
    float ndl = max(dot(NORMAL, LIGHT), 0.0);
    float bands = ndl > 0.73 ? 0.84 : (ndl > 0.32 ? 0.61 : 0.34);
    DIFFUSE_LIGHT += bands * LIGHT_COLOR * ATTENUATION;
}
