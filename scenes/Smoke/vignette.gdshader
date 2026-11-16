shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center = uv - vec2(0.5, 0.5);
    float dist = length(center);

    // Виньетка по краям (как раньше)
    float edge = smoothstep(0.3, 0.7, dist);

    // При intensity = 1.0 должно затемниться ВСЁ, включая центр.
    // Поэтому смешиваем edge-виньетку с полным покрытием:
    float mask = mix(edge, 1.0, intensity);

    vec4 screen_color = texture(screen_texture, uv);
    COLOR = mix(screen_color, vignette_color, mask * intensity);
}