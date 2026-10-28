shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, blend_mix;
stencil_mode read, compare_not_equal, 1;

uniform vec4 outline_color : source_color = vec4(1.0, 0.8, 0.1, 1.0);
uniform float width_px = 3.0;
uniform bool from_center = false;

void vertex() {
    vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    vec2 dir;
    if (from_center) {
        vec4 c = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
        dir = clip.xy / clip.w - c.xy / c.w;
    } else {
        vec3 n = mat3(MODELVIEW_MATRIX) * NORMAL;
        dir = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
    }
    dir = normalize(dir + vec2(1e-6));
    clip.xy += dir * width_px * 2.0 / VIEWPORT_SIZE * clip.w;
    POSITION = clip;
}

void fragment() {
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}