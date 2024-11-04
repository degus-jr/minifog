shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform sampler2D mask_texture : hint_default_white;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	// vec4 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV);
	// vec4 input_color = texture(TEXTURE, UV);
	// vec4 mask = texture(mask_texture, SCREEN_UV);

	vec4 color_a = texture(SCREEN_TEXTURE, FRAGCOORD.xy / SCREEN_PIXEL_SIZE.xy);
	vec4 color_b = texture(TEXTURE, FRAGCOORD.xy / SCREEN_PIXEL_SIZE.xy);
	vec4 mask = texture(mask_texture, FRAGCOORD.xy / SCREEN_PIXEL_SIZE.xy);

	vec4 blended_color = mix(color_a, color_b, mask.r);

	COLOR = mask;

}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
