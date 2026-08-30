shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec4 pixel = textureLod(screen_texture, SCREEN_UV, 0.0);
	float l = pixel.r + pixel.g + pixel.b;
	if (l < 1.8) discard;
	vec4 p1 = textureLod(screen_texture, SCREEN_PIXEL_SIZE + vec2(SCREEN_PIXEL_SIZE.x, 0), 0.0);
	vec4 p2 = textureLod(screen_texture, SCREEN_PIXEL_SIZE + vec2(-SCREEN_PIXEL_SIZE.x, 0), 0.0);
	vec4 p3 = textureLod(screen_texture, SCREEN_PIXEL_SIZE + vec2(0, SCREEN_PIXEL_SIZE.y), 0.0);
	vec4 p4 = textureLod(screen_texture, SCREEN_PIXEL_SIZE + vec2(0, -SCREEN_PIXEL_SIZE.y), 0.0);
	vec4 p5 = textureLod(screen_texture, SCREEN_PIXEL_SIZE + vec2(SCREEN_PIXEL_SIZE.x, SCREEN_PIXEL_SIZE.y), 0.0);
	vec4 p6 = textureLod(screen_texture, SCREEN_PIXEL_SIZE + vec2(-SCREEN_PIXEL_SIZE.x, SCREEN_PIXEL_SIZE.y), 0.0);
	vec4 p7 = textureLod(screen_texture, SCREEN_PIXEL_SIZE + vec2(SCREEN_PIXEL_SIZE.x, -SCREEN_PIXEL_SIZE.y), 0.0);
	vec4 p8 = textureLod(screen_texture, SCREEN_PIXEL_SIZE + vec2(-SCREEN_PIXEL_SIZE.x, -SCREEN_PIXEL_SIZE.y), 0.0);
	vec4 result = (p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8) / 8.0;
	
	COLOR = result;
}
