shader_type canvas_item;

void fragment() {
    vec4 sampled_color = texture(TEXTURE, UV) * COLOR;
    if (UV.y < 0.35) {
        sampled_color.a = 0.0;
    }
    COLOR = sampled_color;
}
