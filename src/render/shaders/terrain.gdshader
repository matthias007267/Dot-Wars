shader_type canvas_item;
render_mode unshaded;

// Nur die Weltoberflaeche: UI und Minimap verwenden weiterhin die Originaltextur.
// Ein Weltpixel bleibt eine Zelle. Alle Details sind deterministisch und GPU-basiert.
uniform float detail_strength : hint_range(0.0, 1.0) = 0.85;
uniform float edge_strength : hint_range(0.0, 1.0) = 0.80;
uniform float vignette_strength : hint_range(0.0, 0.35) = 0.15;

const vec3 TUNNEL = vec3(22.0, 28.0, 36.0) / 255.0;
const vec3 SOFT = vec3(87.0, 201.0, 109.0) / 255.0;
const vec3 MEDIUM = vec3(211.0, 130.0, 44.0) / 255.0;
const vec3 HARD = vec3(92.0, 134.0, 219.0) / 255.0;
const vec3 BEDROCK = vec3(57.0, 63.0, 73.0) / 255.0;

float hash_cell(vec2 p) {
    vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float is_tunnel(vec3 rgb) {
    return 1.0 - step(0.105, distance(rgb, TUNNEL));
}

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    vec3 color = source.rgb;
    vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE);
    float fine = hash_cell(cell + vec2(19.0, 7.0)) - 0.5;
    float broad = hash_cell(floor(cell / 4.0) + vec2(41.0, 11.0)) - 0.5;
    float fleck = hash_cell(cell + vec2(73.0, 37.0));

    float soft = distance(source.rgb, SOFT);
    float medium = distance(source.rgb, MEDIUM);
    float hard = distance(source.rgb, HARD);
    float stone = distance(source.rgb, BEDROCK);
    float empty = distance(source.rgb, TUNNEL);

    bool terrain = soft < 0.13 || medium < 0.13 || hard < 0.13 || stone < 0.10;
    bool corridor = empty < 0.105;

    if (terrain) {
        float shade = 0.88 + detail_strength * (fine * 0.23 + broad * 0.17);
        if (soft < 0.13) {
            // Weiche Erde: leicht organische, matte Oberflaeche.
            color *= shade;
            color += vec3(0.020, 0.060, 0.012) * step(0.89, fleck) * detail_strength;
        } else if (medium < 0.13) {
            // Mittlere Erde: dunklere Brocken und feine Risse.
            color *= shade - 0.035;
            color -= vec3(0.075, 0.045, 0.015) * step(0.91, fleck) * detail_strength;
        } else if (hard < 0.13) {
            // Hartes Mineral: kuehle Splitter und seltene Lichtreflexe.
            color *= shade - 0.065;
            color += vec3(0.065, 0.105, 0.155) * step(0.963, fleck) * detail_strength;
        } else {
            // Unzerstoerbarer Fels: dunkel, schwer, ohne auffaellige Highlights.
            color *= 0.83 + detail_strength * (fine * 0.12 + broad * 0.12);
        }

        if (edge_strength > 0.001) {
            vec2 texel = TEXTURE_PIXEL_SIZE;
            vec2 safe_min = texel * 0.5;
            vec2 safe_max = vec2(1.0) - safe_min;
            vec3 up = texture(TEXTURE, clamp(UV - vec2(0.0, texel.y), safe_min, safe_max)).rgb;
            vec3 down = texture(TEXTURE, clamp(UV + vec2(0.0, texel.y), safe_min, safe_max)).rgb;
            vec3 left = texture(TEXTURE, clamp(UV - vec2(texel.x, 0.0), safe_min, safe_max)).rgb;
            vec3 right = texture(TEXTURE, clamp(UV + vec2(texel.x, 0.0), safe_min, safe_max)).rgb;
            // Obere/linke Kante hell, untere/rechte Kante schattig: Fels wirkt erhaben.
            float bevel = (is_tunnel(up) + is_tunnel(left)) * 0.11
                - (is_tunnel(down) + is_tunnel(right)) * 0.16;
            color *= 1.0 + bevel * edge_strength;
        }
    } else if (corridor) {
        // Ausgegrabene Tunnel bleiben dunkel und wirken gegenueber dem Fels vertieft.
        color *= 0.85 + detail_strength * (fine * 0.16 + broad * 0.08);
        if (edge_strength > 0.001) {
            vec2 texel = TEXTURE_PIXEL_SIZE;
            vec2 safe_min = texel * 0.5;
            vec2 safe_max = vec2(1.0) - safe_min;
            vec3 up = texture(TEXTURE, clamp(UV - vec2(0.0, texel.y), safe_min, safe_max)).rgb;
            vec3 down = texture(TEXTURE, clamp(UV + vec2(0.0, texel.y), safe_min, safe_max)).rgb;
            vec3 left = texture(TEXTURE, clamp(UV - vec2(texel.x, 0.0), safe_min, safe_max)).rgb;
            vec3 right = texture(TEXTURE, clamp(UV + vec2(texel.x, 0.0), safe_min, safe_max)).rgb;
            float upper_wall = step(0.105, distance(up, TUNNEL))
                + step(0.105, distance(left, TUNNEL));
            float lower_wall = step(0.105, distance(down, TUNNEL))
                + step(0.105, distance(right, TUNNEL));
            color += vec3(0.022, 0.031, 0.042) * upper_wall * edge_strength;
            color *= 1.0 - 0.14 * min(lower_wall, 1.0) * edge_strength;
        }
    }
    // Marker, Gebaeude, beschaedigte Zellen und Kerne bleiben klar unterscheidbar.
    // Der Farbfilter wirkt ausschliesslich auf diesen WorldRenderer-Sprite.
    color = (color - vec3(0.5)) * 1.055 + vec3(0.5);
    vec2 screen_center = SCREEN_UV * 2.0 - vec2(1.0);
    float vignette = 1.0 - vignette_strength
        * smoothstep(0.18, 1.40, dot(screen_center, screen_center));
    COLOR = vec4(clamp(color * vignette, vec3(0.0), vec3(1.0)), source.a);
}
