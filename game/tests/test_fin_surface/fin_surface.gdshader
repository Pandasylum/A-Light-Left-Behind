// fin_surface.gdshader : retour visuel de fin de surface (Godot 4.x, Forward+)
// Valeurs PROVISOIRES (à régler après essai). Matériau en next_pass de la surface nettoyée.
// Un seul passage lent d'un voile froid, du bas vers le haut de la surface, puis extinction.
// Pas de particules, pas de flash, pas de changement de couleur durable.
// Piloté par `progress` (0 -> 1, tween ~1,4 s, à brancher côté Godot Engineering).
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3  tint : source_color = vec3(0.72, 0.86, 1.0); // froid, dans la palette de la pièce
uniform float peak = 0.12;          // intensité max (additif, linéaire). Retenu 0,12 (Direction, 2026-11-12, provisoire) ; 0,05 = très discret
uniform float band_width = 0.22;    // largeur du voile (fraction de la hauteur UV)
uniform float edge_boost = 0.6;     // renfort léger sur les joints (via normal map), 0 = aucun
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;

float bump(float x, float c, float w) {
	float d = abs(x - c) / w;
	return 1.0 - smoothstep(0.0, 1.0, d);
}

void fragment() {
	// voile qui monte : centre de -w à 1+w pour partir et finir hors surface
	float c = mix(-band_width, 1.0 + band_width, progress);
	float v = 1.0 - UV.y;                       // UV.y = 0 en haut : v croît vers le haut
	float band = bump(v, c, band_width);
	// l'ensemble s'éteint sur les 20 derniers % pour ne laisser aucune trace
	float fade = 1.0 - smoothstep(0.8, 1.0, progress);
	// relief : le voile accroche les arêtes de joints plutôt que de plaquer un aplat
	vec3 n = texture(normal_tex, UV).rgb * 2.0 - 1.0;
	float relief = clamp(length(n.xy) * 2.5, 0.0, 1.0);
	float k = band * fade * (1.0 + edge_boost * relief);
	ALBEDO = tint * peak * k;
}
