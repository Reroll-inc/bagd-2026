shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

const int COLOR_AMNT = 4;
const vec3 colors[COLOR_AMNT] = {
	vec3(0.513725, 0.533333, 0.737255),
	vec3(0.415686, 0.560784, 0.211765),
	vec3(0.490196, 0.298039, 0.486275),
	vec3(0.65098 , 0.298039, 0.129412)
};

uniform float x_pos;
const float step_size = 300.0;
const float half_step = step_size/2.0;
const float wrap = step_size*float(COLOR_AMNT);

void fragment() {
	//COLOR = textureLod(screen_texture, SCREEN_UV, 0.0);
	float wraped_pos = x_pos - wrap*floor(x_pos / wrap);
	float wraped_pos_2 = wraped_pos - wrap;
	if (COLOR.a == 0.0) discard;
	float t = 0.0;
	for(int i = 0; i < COLOR_AMNT; ++i) {
		float tx = float(i)*step_size;
		float d = 1.0 - min(distance(wraped_pos, tx), step_size) / step_size;
		float d2 = 1.0 - min(distance(wraped_pos_2, tx), step_size) / step_size;
		
		vec3 c = colors[i];
		vec3 base = COLOR.rgb;
		if (distance(c, COLOR.rgb) < 0.01) t = smoothstep(0.1, 1.0, max(d, d2));
	}
	float f = mix(0.0, 0.3, t);
	vec4 light = vec4(1.0, 0.6941, 0.1882, 1.0);
	COLOR = COLOR*0.9 + light*f;
}
