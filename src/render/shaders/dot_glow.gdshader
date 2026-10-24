shader_type canvas_item;
render_mode unshaded;

// Gemeinsamer GPU-Effekt fuer Arbeiter- und Energie-Textur.
// Nur vier benachbarte Texel: kein eigener Node, Licht oder Partikel pro Dot.
uniform float glow_strength : hint_range(0.0, 1.0) = 0.85;
uniform float dot_brightness : hint_range(1.0, 1.5) = 1.16;

void fragment() {
    vec4 dot_color = texture(TEXTURE, UV);
    if (dot_color.a > 0.01) {
        // Der eigentliche Dot bleibt pixelgenau scharf.
        COLOR = vec4(min(dot_color.rgb * dot_brightness, vec3(1.0)), dot_color.a);
    } else {
        vec2 texel = TEXTURE_PIXEL_SIZE;
        vec2 safe_min = texel * 0.5;
        vec2 safe_max = vec2(1.0) - safe_min;
        vec4 up = texture(TEXTURE, clamp(UV - vec2(0.0, texel.y), safe_min, safe_max));
        vec4 down = texture(TEXTURE, clamp(UV + vec2(0.0, texel.y), safe_min, safe_max));
        vec4 left = texture(TEXTURE, clamp(UV - vec2(texel.x, 0.0), safe_min, safe_max));
        vec4 right = texture(TEXTURE, clamp(UV + vec2(texel.x, 0.0), safe_min, safe_max));
        float amount = up.a + down.a + left.a + right.a;
        if (amount > 0.01) {
            vec3 tint = (up.rgb * up.a + down.rgb * down.a
                + left.rgb * left.a + right.rgb * right.a) / amount;
            COLOR = vec4(tint, min(amount * glow_strength * 0.19, 0.42));
        } else {
            COLOR = vec4(0.0);
        }
    }
}
