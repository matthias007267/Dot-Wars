shader_type canvas_item;
render_mode unshaded;

// The simulation texture remains one texel per cell; detail exists only on the GPU.
uniform float detail_strength : hint_range(0.0, 1.0) = 0.85;
uniform float edge_strength : hint_range(0.0, 1.0) = 0.8;
uniform float vignette_strength : hint_range(0.0, 0.35) = 0.15;
uniform sampler2D cavern_light : filter_linear, repeat_disable;
uniform bool lighting_enabled = false;
uniform float ambient_multiplier = 1.0;
uniform vec2 cell_origin = vec2(0.0);
uniform sampler2D stone_floor : source_color, filter_nearest, repeat_enable;
uniform sampler2D floor_history : filter_nearest, repeat_disable;
uniform bool floor_history_enabled = false;
const vec3 TUNNEL = vec3(22.0, 28.0, 36.0) / 255.0;
const vec3 SOFT = vec3(87.0, 201.0, 109.0) / 255.0;
const vec3 MEDIUM = vec3(211.0, 130.0, 44.0) / 255.0;
const vec3 HARD = vec3(92.0, 134.0, 219.0) / 255.0;
const vec3 BEDROCK = vec3(57.0, 63.0, 73.0) / 255.0;

float hash_cell(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float is_corridor(vec3 rgb) {
    return 1.0 - step(0.105, distance(rgb, TUNNEL));
}

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    vec2 world = UV / TEXTURE_PIXEL_SIZE;
    vec2 cell = floor(world) + cell_origin;
    vec2 p = floor(fract(world) * 12.0) / 12.0;
    float seed = hash_cell(cell);
    float grain = hash_cell(cell * 13.0 + floor(p * 12.0));
    bool corridor = distance(source.rgb, TUNNEL) < 0.105;
    bool soft = distance(source.rgb, SOFT) < 0.13;
    bool medium = distance(source.rgb, MEDIUM) < 0.13;
    bool hard = distance(source.rgb, HARD) < 0.13;
    bool rock = distance(source.rgb, BEDROCK) < 0.10;
    vec3 light = lighting_enabled ? texture(cavern_light, UV).rgb : vec3(0.0);
    vec3 color = source.rgb;
    if (corridor) {
        // World-aligned, flat slate floor, with a subtle persistent mining tint.
        vec2 floor_uv = floor((world + cell_origin) * 12.0) / 96.0;
        vec3 slate = texture(stone_floor, floor_uv).rgb;
        float dug = floor_history_enabled ? step(0.5 / 255.0, texture(floor_history, UV).r) : 0.0;
        vec3 tint = mix(vec3(0.91, 0.99, 1.07), vec3(1.10, 1.01, 0.91), dug);
        color = mix(TUNNEL, (slate * 0.68 + vec3(0.018)) * tint, detail_strength);
        float wall = 4.0 - is_corridor(texture(TEXTURE, clamp(UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0), TEXTURE_PIXEL_SIZE * 0.5, vec2(1.0) - TEXTURE_PIXEL_SIZE * 0.5)).rgb) - is_corridor(texture(TEXTURE, clamp(UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0), TEXTURE_PIXEL_SIZE * 0.5, vec2(1.0) - TEXTURE_PIXEL_SIZE * 0.5)).rgb) - is_corridor(texture(TEXTURE, clamp(UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y), TEXTURE_PIXEL_SIZE * 0.5, vec2(1.0) - TEXTURE_PIXEL_SIZE * 0.5)).rgb) - is_corridor(texture(TEXTURE, clamp(UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y), TEXTURE_PIXEL_SIZE * 0.5, vec2(1.0) - TEXTURE_PIXEL_SIZE * 0.5)).rgb);
        color *= 1.0 - min(wall, 2.0) * 0.12 * edge_strength;
        color += light * 0.38;
    } else if (soft || medium || hard || rock) {
        vec3 stone = vec3(0.075, 0.103, 0.132);
        stone *= 0.72 + seed * 0.42 + grain * 0.14;
        // Individual chipped blocks: highlights on top/left, deep joints below.
        float bevel = step(p.y, 0.085) * 0.05 + step(p.x, 0.085) * 0.025;
        bevel -= step(0.83, p.y) * 0.035 + step(0.91, p.x) * 0.025;
        float crack = step(0.96, hash_cell(cell + floor(p * 4.0))) * 0.04;
        stone += vec3(bevel - crack) * detail_strength;
        vec3 mineral = vec3(0.04, 0.42, 1.0);
        if (soft) { mineral = vec3(0.09, 0.85, 0.22); }
        else if (medium) { mineral = vec3(1.0, 0.48, 0.025); }
        stone += mineral * (rock ? 0.0 : 0.025);
        // Sparse facets are visual veins of existing materials, not new deposits.
        float vein = step(0.66, seed) * (1.0 - float(rock));
        vec2 q = (p - vec2(0.48, 0.49)) * vec2(1.9, 1.25);
        float diamond = 1.0 - step(0.48, abs(q.x) + abs(q.y));
        float facet = (q.x < 0.0 ? 0.7 : 0.35) + (q.y < -0.05 ? 0.35 : 0.0);
        stone = mix(stone, mineral * facet, vein * diamond * detail_strength);
        stone += mineral * vein * diamond * step(abs(q.x), 0.075) * 0.27 * detail_strength;
        stone += mineral * vein * max(0.0, 0.2 - length(q) * 0.15) * 0.16;
        color = mix(source.rgb, stone, detail_strength);
        float rim = is_corridor(texture(TEXTURE, clamp(UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y), TEXTURE_PIXEL_SIZE * 0.5, vec2(1.0) - TEXTURE_PIXEL_SIZE * 0.5)).rgb) + is_corridor(texture(TEXTURE, clamp(UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0), TEXTURE_PIXEL_SIZE * 0.5, vec2(1.0) - TEXTURE_PIXEL_SIZE * 0.5)).rgb);
        color += vec3(0.035, 0.045, 0.055) * rim * edge_strength;
        color += light * 0.18;
    } else {
        // Existing building/mission marker colors are subdued beneath the new art.
        color *= 0.28;
        color += light * 0.16;
    }
    vec2 screen_center = SCREEN_UV * 2.0 - vec2(1.0);
    float vignette = 1.0 - vignette_strength * smoothstep(0.18, 1.40, dot(screen_center, screen_center));
    COLOR = vec4(clamp(color * vignette * ambient_multiplier, vec3(0.0), vec3(1.0)), source.a);
}
