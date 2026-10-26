shader_type canvas_item;
render_mode unshaded;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.85;
uniform float dot_brightness : hint_range(1.0, 1.5) = 1.16;
// 0 worker, 1 warrior, 2 energy. Tier marks use actual own upgrades only.
uniform int unit_kind = 0;
uniform int upgrade_marks = 0;

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    vec2 p = floor(fract(UV / TEXTURE_PIXEL_SIZE) * 10.0) / 10.0;
    vec3 tint = source.rgb;
    if (distance(tint, vec3(255.0, 122.0, 89.0) / 255.0) < 0.02) tint = vec3(1.0, 0.20, 0.24);
    if (unit_kind == 1 && distance(tint, vec3(245.0, 78.0, 80.0) / 255.0) < 0.02) tint = vec3(1.0, 0.77, 0.16);
    if (source.a > 0.01) {
        float border = step(0.1, p.x) * step(p.x, 0.8) * step(0.1, p.y) * step(p.y, 0.8);
        float inset = step(0.2, p.x) * step(p.x, 0.7) * step(0.2, p.y) * step(p.y, 0.7);
        vec3 color = tint * (0.27 + 0.55 * border + 0.38 * inset);
        color += tint * step(p.y, 0.2) * border * 0.26;
        if (unit_kind == 0) {
            // Helmet visor and a dark tool notch keep workers legible at close zoom.
            color *= 1.0 - step(0.3, p.y) * step(p.y, 0.4) * inset * 0.6;
        } else if (unit_kind == 1) {
            float shield = step(abs(p.x - 0.45), 0.12) + step(abs(p.y - 0.45), 0.09);
            color = mix(color, vec3(1.0, 0.94, 0.65), min(shield, 1.0) * inset * 0.6);
        } else {
            color = mix(tint * 0.6, vec3(0.85, 1.0, 1.0), inset * 0.75);
        }
        bool friendly = distance(source.rgb, vec3(1.0, 228.0/255.0, 94.0/255.0)) < 0.04;
        if (friendly && unit_kind == 0 && upgrade_marks > 0 && p.y > 0.65 && p.y < 0.85) {
            if ((upgrade_marks >= 1 && p.x < 0.35) || (upgrade_marks >= 2 && p.x > 0.55)) color = vec3(0.85, 1.0, 1.0);
        }
        float silhouette = step(0.2, p.x) * step(p.x, 0.7) * step(0.2, p.y) * step(p.y, 0.7);
        if (unit_kind == 2) silhouette = step(0.3, p.x) * step(p.x, 0.6) * step(0.3, p.y) * step(p.y, 0.6);
        COLOR = vec4(min(color * dot_brightness, vec3(1.0)), source.a * silhouette);
    } else {
        vec2 texel = TEXTURE_PIXEL_SIZE;
        vec2 lo = texel * 0.5;
        vec2 hi = vec2(1.0) - lo;
        vec4 a = texture(TEXTURE, clamp(UV + vec2(texel.x, 0.0), lo, hi));
        vec4 b = texture(TEXTURE, clamp(UV - vec2(texel.x, 0.0), lo, hi));
        vec4 c = texture(TEXTURE, clamp(UV + vec2(0.0, texel.y), lo, hi));
        vec4 d = texture(TEXTURE, clamp(UV - vec2(0.0, texel.y), lo, hi));
        float amount = a.a + b.a + c.a + d.a;
        vec3 glow = (a.rgb * a.a + b.rgb * b.a + c.rgb * c.a + d.rgb * d.a) / max(amount, 0.001);
        if (distance(glow, vec3(255.0,122.0,89.0)/255.0) < 0.02) glow = vec3(1.0,0.20,0.24);
        if (unit_kind == 1 && distance(glow, vec3(245.0,78.0,80.0)/255.0) < 0.02) glow = vec3(1.0,0.77,0.16);
        COLOR = vec4(glow, min(amount * glow_strength * 0.12, 0.24));
    }
}
