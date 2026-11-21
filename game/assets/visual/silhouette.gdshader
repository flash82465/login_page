// Matière des silhouettes OKÉLUN (mission 005).
// Couleur unie très sombre, sans éclairage, et liseré discret de contre-jour : il n'apparaît que
// sur les bords du volume (là où la surface fuit le regard) et surtout sur ceux tournés vers le
// haut et l'arrière-plan. Pas de contour épais : la largeur du liseré dépend de la courbure.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 body_color : source_color = vec4(0.1, 0.066, 0.046, 1.0);
uniform vec4 rim_color : source_color = vec4(0.86, 0.46, 0.18, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.5;
uniform float rim_power : hint_range(1.0, 8.0) = 3.5;
uniform vec4 flash_color : source_color = vec4(1.0, 0.3, 0.25, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 n = normalize(NORMAL);
	float edge = pow(1.0 - abs(dot(n, normalize(VIEW))), rim_power);
	float backlight = clamp(dot(n, normalize(vec3(0.0, 0.75, -0.65))) * 0.6 + 0.4, 0.0, 1.0);
	vec3 color = mix(body_color.rgb, rim_color.rgb, clamp(edge * backlight * rim_strength, 0.0, 1.0));
	ALBEDO = mix(color, flash_color.rgb, flash_amount);
}
