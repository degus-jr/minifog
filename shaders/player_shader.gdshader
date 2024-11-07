shader_type canvas_item;

uniform sampler2D mask_texture : hint_default_white;

void fragment() {
	vec4 input_color = texture(TEXTURE, UV);
	vec4 mask = texture(mask_texture, UV);

    input_color.a = mask.r;
	COLOR = input_color;
}
