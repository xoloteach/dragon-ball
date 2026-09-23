shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform float outline_width = 0.018;
uniform vec4 outline_color : source_color = vec4(0.07, 0.04, 0.045, 1.0);

void vertex() { VERTEX += NORMAL * outline_width; }
void fragment() { ALBEDO = outline_color.rgb; }

