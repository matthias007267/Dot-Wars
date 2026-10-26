shader_type canvas_item;
render_mode unshaded;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.85;
uniform float dot_brightness : hint_range(1.0, 1.5) = 1.16;
// 0 worker, 1 warrior, 2 energy. Own worker marks use existing research only.
uniform int unit_kind = 0;
uniform int upgrade_marks = 0;
uniform bool sprites_enabled = false;
uniform bool sprite_detail = true;
uniform sampler2D sprite_body : source_color, filter_nearest, repeat_disable;
uniform sampler2D sprite_team : filter_nearest, repeat_disable;
uniform sampler2D unit_details : filter_nearest, repeat_disable;
uniform vec2 sprite_grid = vec2(1.0, 4.0);
uniform float sprite_cell_size = 32.0;
uniform float sprite_frame_ticks = 4.0;
uniform int simulation_tick = 0;
uniform vec3 sprite_faction_0;
uniform vec3 sprite_faction_1;
uniform vec3 sprite_faction_2;
uniform vec3 sprite_faction_3;

vec3 faction_color(float owner) {
    if (owner < 0.5) return sprite_faction_0;
    if (owner < 1.5) return sprite_faction_1;
    if (owner < 2.5) return sprite_faction_2;
    return sprite_faction_3;
}

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    vec2 p = floor(fract(UV / TEXTURE_PIXEL_SIZE) * 10.0) / 10.0;
    vec3 tint = source.rgb;
    if (distance(tint, vec3(255.0, 122.0, 89.0) / 255.0) < 0.02) tint = vec3(1.0, 0.20, 0.24);
    if (unit_kind == 1 && distance(tint, vec3(245.0, 78.0, 80.0) / 255.0) < 0.02) tint = vec3(1.0, 0.77, 0.16);
    if (source.a > 0.01) {
      if (sprites_enabled && unit_kind < 2) {
        vec4 data = floor(texture(unit_details, UV) * 255.0 + 0.5);
        vec3 team = faction_color(data.b);
        if (sprite_detail) {
            vec2 local = fract(UV / TEXTURE_PIXEL_SIZE);
            // Squares never turn. The activity byte only controls a central glint.
            vec2 pixel = clamp(floor(local * sprite_cell_size), vec2(0.0), vec2(sprite_cell_size - 1.0));
            float frame = mod(floor(float(simulation_tick) / sprite_frame_ticks), sprite_grid.x);
            vec2 atlas_uv = (vec2(frame, data.r) + (pixel + 0.5) / sprite_cell_size) / sprite_grid;
            vec4 body = texture(sprite_body, atlas_uv);
            vec4 mask = texture(sprite_team, atlas_uv);
            vec3 color = mix(body.rgb, team * mask.rgb, mask.a);
            float core = max(abs(local.x - 0.5), abs(local.y - 0.5));
            if (unit_kind == 0) {
                if (data.a > 0.5 && core > 0.10 && core < 0.12 + data.a * 0.025) color = vec3(0.85, 1.0, 1.0);
                if ((data.g == 2.0 || data.g == 4.0) && core < 0.09)
                    color *= 0.72 + 0.28 * mod(floor(float(simulation_tick) / 4.0), 2.0);
            } else if (data.g == 2.0 && core < 0.14) {
                color = mix(color, vec3(1.0), 0.45);
            }
            COLOR = vec4(color, max(body.a, mask.a) * source.a);
        } else {
            // Both types keep their square footprint even in the compact view.
            vec2 local = fract(UV / TEXTURE_PIXEL_SIZE) - 0.5;
            vec2 p = abs(local);
            float radius = max(p.x, p.y);
            float shape = step(radius, 0.46);
            vec3 color = team;
            if (radius > 0.40) color = vec3(0.035, 0.055, 0.08);
            if (unit_kind == 0 && radius < 0.10) color = vec3(0.88, 0.94, 1.0);
            if (unit_kind == 1 && radius < 0.29) {
                color = vec3(0.035, 0.055, 0.08);
                if (radius < 0.13) color = team;
                if (min(p.x, p.y) > 0.17) color = vec3(0.7, 0.76, 0.82);
                if (data.a >= 2.0 && min(p.x, p.y) > 0.12 && radius > 0.22) color = vec3(0.7, 0.76, 0.82);
                if (data.a >= 3.0 && radius > 0.13 && radius < 0.17) color = vec3(0.45, 0.52, 0.60);
            }
            COLOR = vec4(color, source.a * shape);
        }
      } else {
        float border = step(0.1, p.x) * step(p.x, 0.8) * step(0.1, p.y) * step(p.y, 0.8);
        float inset = step(0.2, p.x) * step(p.x, 0.7) * step(0.2, p.y) * step(p.y, 0.7);
        vec3 color = tint * (0.27 + 0.55 * border + 0.38 * inset);
        color += tint * step(p.y, 0.2) * border * 0.26;
        if (unit_kind == 0) {
            float core = step(max(abs(p.x - 0.45), abs(p.y - 0.45)), 0.10);
            color = mix(color, vec3(0.85, 0.94, 1.0), core);
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
      }
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
        if (sprites_enabled && unit_kind < 2) {
            vec3 ta = faction_color(floor(texture(unit_details, clamp(UV + vec2(texel.x, 0.0), lo, hi)).b * 255.0 + 0.5));
            vec3 tb = faction_color(floor(texture(unit_details, clamp(UV - vec2(texel.x, 0.0), lo, hi)).b * 255.0 + 0.5));
            vec3 tc = faction_color(floor(texture(unit_details, clamp(UV + vec2(0.0, texel.y), lo, hi)).b * 255.0 + 0.5));
            vec3 td = faction_color(floor(texture(unit_details, clamp(UV - vec2(0.0, texel.y), lo, hi)).b * 255.0 + 0.5));
            glow = (ta * a.a + tb * b.a + tc * c.a + td * d.a) / max(amount, 0.001);
        }
        COLOR = vec4(glow, min(amount * glow_strength * 0.12, 0.24));
    }
}
