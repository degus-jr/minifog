shader_type canvas_item;

uniform sampler2D mask_texture : hint_default_white;
uniform float alpha_ceil = 0.5;

void fragment() {
	vec4 input_color = texture(TEXTURE, UV);
	vec4 mask = texture(mask_texture, UV);

    input_color.a = alpha_ceil - (1.0 - mask.r) * alpha_ceil;
	COLOR = input_color;
}
