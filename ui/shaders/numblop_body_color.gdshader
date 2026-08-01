shader_type canvas_item;

uniform vec4 target_color : source_color = vec4(0.7804, 0.8824, 0.2627, 1.0);
uniform float recolor_strength : hint_range(0.0, 1.0) = 0.0;

const float SOURCE_BRIGHTNESS = 0.8824;


void fragment() {
    vec4 pixel = texture(TEXTURE, UV);
    float green_over_red = smoothstep(0.015, 0.075, pixel.g - pixel.r);
    float green_over_blue = smoothstep(0.05, 0.18, pixel.g - pixel.b);
    float color_mask = green_over_red * green_over_blue * pixel.a;
    float brightness = max(pixel.r, max(pixel.g, pixel.b)) / SOURCE_BRIGHTNESS;
    vec3 recolored = clamp(target_color.rgb * brightness, vec3(0.0), vec3(1.0));
    pixel.rgb = mix(pixel.rgb, recolored, color_mask * recolor_strength);
    COLOR = pixel;
}
