shader_type spatial;
render_mode diffuse_toon, specular_disabled;

varying vec3 world_pos;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float broad = noise2(world_pos.xz * .18);
    float fine = noise2(world_pos.xz * 1.25);
    float grain = noise2(world_pos.xz * 4.0);
    float value = broad * .58 + fine * .33 + grain * .09;
    vec3 red_sand = vec3(.18, .11, .075);
    vec3 warm_sand = vec3(.32, .21, .145);
    vec3 cool_shade = vec3(.14, .15, .16);
    vec3 pigment = mix(red_sand, warm_sand, smoothstep(.20, .79, value));
    pigment = mix(pigment, cool_shade, smoothstep(.60, .82, broad) * .55);
    ALBEDO = pigment;
    ROUGHNESS = 1.0;
}

void light() {
    float ndl = max(dot(NORMAL, LIGHT), 0.0);
    float band = ndl > .65 ? .88 : (ndl > .25 ? .62 : .38);
    DIFFUSE_LIGHT += LIGHT_COLOR * band * ATTENUATION;
}
