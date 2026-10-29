shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear;

uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float grain_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float aberration_strength : hint_range(0.0, 0.05) = 0.015;
uniform float flicker_intensity : hint_range(0.0, 0.3) = 0.05;
uniform float sepia_amount : hint_range(0.0, 1.0) = 0.3;
uniform float fade_blacks : hint_range(0.0, 0.5) = 0.1;

uniform float barrel_strength : hint_range(0.0, 0.8) = 0.35;
// Зум: >1 приближает картинку и скрывает растянутые края
uniform float zoom : hint_range(1.0, 1.5) = 1.15;

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = SCREEN_UV;

    // 1. Зум (приближение) — применяем ДО искажения
    vec2 centered = uv - vec2(0.5);
    centered /= zoom; // делим на zoom => картинка крупнее

    // 2. Эффект бочки (Fisheye / Barrel distortion)
    float r2 = dot(centered, centered);
    centered *= (1.0 + barrel_strength * r2);
    vec2 distorted_uv = centered + vec2(0.5);

    // Клампим, чтобы не было чёрных краёв
    vec2 final_uv = clamp(distorted_uv, vec2(0.0), vec2(1.0));

    // 3. Хроматическая аберрация
    vec2 to_center = final_uv - vec2(0.5);
    float dist_from_center = length(to_center);
    float aberr = aberration_strength * dist_from_center;

    vec3 color;
    color.r = texture(SCREEN_TEXTURE, final_uv + to_center * aberr).r;
    color.g = texture(SCREEN_TEXTURE, final_uv).g;
    color.b = texture(SCREEN_TEXTURE, final_uv - to_center * aberr).b;

    // 4. Зерно
    float grain = random(final_uv + vec2(TIME * 0.1, TIME * 0.05));
    color += (grain - 0.5) * grain_intensity;

    // 5. Мерцание
    float flicker = 1.0 + (random(vec2(TIME, 0.0)) - 0.5) * flicker_intensity;
    color *= flicker;

    // 6. Сепия
    float sepia_lum = dot(color, vec3(0.299, 0.587, 0.114));
    vec3 sepia_color = vec3(sepia_lum * 1.07, sepia_lum * 0.74, sepia_lum * 0.43);
    color = mix(color, sepia_color, sepia_amount);

    // 7. Fade blacks
    color = mix(color, color + vec3(fade_blacks), 1.0 - smoothstep(0.0, 0.2, dot(color, vec3(0.333))));

    // 8. Виньетка
    float vignette = smoothstep(0.8, 0.3, dist_from_center * 1.5);
    color *= mix(1.0, vignette, vignette_intensity);

    COLOR = vec4(color, 1.0);
}