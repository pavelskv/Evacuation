shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_nearest;

uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.1;
uniform float grain_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float aberration_strength : hint_range(0.0, 0.05) = 0.02;
uniform float flicker_intensity : hint_range(0.0, 0.3) = 0.05;
uniform float sepia_amount : hint_range(0.0, 1.0) = 0.3;
uniform float fade_blacks : hint_range(0.0, 0.5) = 0.1;
uniform float barrel_distortion : hint_range(0.0, 3.0) = 1.2;
uniform float zoom_scale : hint_range(0.5, 1.5) = 0.85;

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

vec2 barrel_distort(vec2 uv, float k) {
    vec2 centered = uv - 0.5;
    float r2 = dot(centered, centered);
    centered *= 1.0 + k * r2;
    return centered + 0.5;
}

void fragment() {
    vec2 uv = SCREEN_UV;

    // Применяем бочкообразную дисторсию (очень сильную для дверного глазка)
    uv = barrel_distort(uv, barrel_distortion);

    // Масштабируем, чтобы картинка вписывалась в экран (компенсация дисторсии)
    uv = (uv - 0.5) * zoom_scale + 0.5;

    // Хроматическая аберрация с радиальным градиентом
    vec2 to_center = uv - 0.5;
    float dist = length(to_center);
    vec2 dir = normalize(to_center + 0.0001);
    float current_aberration = aberration_strength * dist;

    float r = texture(SCREEN_TEXTURE, uv + dir * current_aberration).r;
    float g = texture(SCREEN_TEXTURE, uv).g;
    float b = texture(SCREEN_TEXTURE, uv - dir * current_aberration).b;
    vec3 col = vec3(r, g, b);

    // Лёгкая виньетка (почти незаметная)
    vec2 center = uv - 0.5;
    float vignette_dist = dot(center, center);
    col *= 1.0 - vignette_dist * vignette_intensity;

    // Зерно пленки
    float grain = random(uv * TIME * 50.0) * grain_intensity;
    col += grain - (grain_intensity * 0.5);

    // Мерцание экспозиции
    float flicker = 1.0 + (random(vec2(TIME * 15.0, 0.0)) - 0.5) * flicker_intensity;
    col *= flicker;

    // Выцветание
    col = mix(col, vec3(0.4, 0.38, 0.35), fade_blacks);

    // Сепия
    vec3 sepia = vec3(
        dot(col, vec3(0.393, 0.769, 0.189)),
        dot(col, vec3(0.349, 0.686, 0.168)),
        dot(col, vec3(0.272, 0.534, 0.131))
    );
    col = mix(col, sepia, sepia_amount);

    COLOR = vec4(col, 1.0);
}