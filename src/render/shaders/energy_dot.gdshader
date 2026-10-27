shader_type canvas_item;
render_mode unshaded;

uniform float glow_strength : hint_range(0.0, 1.0) = 0.95;
uniform bool sprite_detail = true;

void fragment() {
    // One texel per occupied world cell, no neighbor sampling into hidden cells.
    vec4 source = texture(TEXTURE, UV);
    vec2 local = fract(UV / TEXTURE_PIXEL_SIZE);
    vec2 pixel = (floor(local * 16.0) + 0.5) / 16.0 - 0.5;
    float radius = max(abs(pixel.x), abs(pixel.y));
    vec3 team = source.rgb;
    vec3 color = team;
    float alpha = 0.0;
    if (source.a > 0.01) {
        bool buffered = source.a < 0.75;
        vec3 inner = buffered ? vec3(1.0, 0.66, 0.24) : vec3(0.28, 0.94, 1.0);
        if (sprite_detail) {
            // Eight-pixel square: team rim, dark gap, cyan light, white 2x2 core.
            if (radius < 0.25) {
                alpha = 1.0;
                if (radius < 0.0625) color = vec3(0.95, 1.0, 1.0);
                else if (radius < 0.125) color = inner;
                else if (radius < 0.1875) color = vec3(0.025, 0.09, 0.12);
            } else {
                alpha = glow_strength * 0.25 * exp(-20.0 * (radius - 0.25));
            }
        } else {
            // At overview scale the team color survives subpixel core/rim details.
            color = mix(team, vec3(0.95, 1.0, 1.0), 0.18);
            alpha = radius < 0.32 ? 1.0 : glow_strength * 0.12;
        }
    }
    COLOR = vec4(color, alpha);
}
