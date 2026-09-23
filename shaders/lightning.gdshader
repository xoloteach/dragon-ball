shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 bolt_color : source_color = vec4(1.0, .88, .24, 1.0);
uniform float strength = 0.0;

void vertex() {
    VERTEX.x += sin(TIME * 17.0 + VERTEX.y * 12.0 + UV.x * 11.0) * .035;
}

void fragment() {
    float blink = step(.13, sin(TIME * 23.0 + floor(UV.x * 8.0) * 2.9));
    EMISSION = bolt_color.rgb * 4.0;
    ALBEDO = bolt_color.rgb;
    ALPHA = bolt_color.a * strength * blink * COLOR.a;
}
