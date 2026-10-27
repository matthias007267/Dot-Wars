shader_type canvas_item;
render_mode unshaded;
varying vec2 grid_position;
void vertex() { grid_position = VERTEX; }
void fragment() {
    // Only energized cores use high alpha. Dark infrastructure and previews stay still.
    if (COLOR.a > 0.70) {
        float flow = 0.5 + 0.5 * sin((grid_position.x + grid_position.y) * 4.0 - TIME * 6.0);
        float pulse = 0.90 + 0.10 * sin(TIME * 3.0);
        COLOR.rgb *= (0.65 + 0.35 * flow) * pulse;
    }
}
