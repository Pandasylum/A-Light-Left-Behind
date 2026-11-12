// fin_surface.gdshader : retour visuel de fin de surface (Godot 4.x, Forward+)
// Valeurs PROVISOIRES (à régler après essai). Matériau en next_pass de la face de la surface terminée.
// Un seul passage lent d'un voile froid qui MONTE le long de la surface, puis extinction.
// Pas de particules, pas de flash, pas de changement de couleur durable.
// Piloté par `progress` (0 -> 1, tween 1,4 s linéaire). Le MÊME progress est écrit sur le matériau de
// toutes les faces de la surface : aucun décalage entre faces.
//
// Ne lit NI UV NI UV2 : la position du voile vient de la position MONDE du fragment, mesurée sur un
// « chemin de balayage » commun à toutes les faces d'une surface (abscisse en mètres) :
//   - mode 0 (vertical)  : abscisse = decalage + (y monde - balayage_y0)   -> mur, panneau de noyau, contremarche
//   - mode 1 (polaire)   : abscisse = decalage + arc(angle monde) * rayon  -> dessus de marche
// Marche : la contremarche couvre [0, H], le dessus [H, H + profondeur] à partir de l'arête commune.
// Le voile monte la contremarche puis traverse le dessus, sans saut à l'arête.
// Les uniforms balayage_* sont calculés par fin_surface_balayage.gd (FinSurfaceSweep) d'après les faces
// de la surface. Les uniforms proj_* (SurfaceMapping.WorldProjection.apply_to) ne servent qu'à edge_boost.
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3  tint : source_color = vec3(0.72, 0.86, 1.0); // froid, dans la palette de la pièce
uniform float peak = 0.12;          // intensité max (additif, linéaire). Retenu 0,12 (Direction, 2026-11-12, provisoire) ; 0,05 = très discret
uniform float band_width = 0.22;    // largeur du voile (fraction de la longueur du chemin)
uniform float edge_boost = 0.0;     // renfort léger sur les joints (via normal map, projection monde), 0 = aucun (retenu)

group_uniforms balayage;
uniform int   balayage_mode = 0;           // 0 = vertical (y monde), 1 = polaire (angle monde autour de l'axe de la tour)
uniform float balayage_longueur = 1.0;     // m, longueur TOTALE du chemin (identique pour toutes les faces de la surface)
uniform float balayage_decalage = 0.0;     // m, abscisse du bord de départ de CETTE face sur le chemin
uniform float balayage_y0 = 0.0;           // mode 0 : y monde du bord bas de la face
uniform vec2  balayage_axe_xz = vec2(0.0); // mode 1 : position XZ monde de l'axe vertical
uniform float balayage_angle0 = 0.0;       // mode 1 : angle monde atan(-z, x) du bord de départ (rad)
uniform float balayage_sens = 1.0;         // mode 1 : +1 si la face s'étend vers les angles croissants, -1 sinon
uniform float balayage_rayon = 1.0;        // mode 1 : rayon de référence (m) qui convertit l'angle en longueur d'arc

group_uniforms projection;
uniform int proj_mode = 0; // 0 = plan, 1 = cylindre d'axe vertical (mêmes noms que pierre_nettoyable.gdshader)
uniform vec3 proj_axe_u = vec3(1.0, 0.0, 0.0);
uniform vec3 proj_axe_v = vec3(0.0, 0.0, 1.0);
uniform vec2 proj_axe_xz = vec2(0.0);
uniform float proj_rayon_ref = 1.0;
uniform float proj_tuile_m = 1.0;

group_uniforms joints;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 uv_echelle = vec2(1.0); // même valeur que le matériau de pierre de la face (edge_boost seulement)

varying vec3 pos_monde;

float bump(float x, float c, float w) {
	float d = abs(x - c) / w;
	return 1.0 - smoothstep(0.0, 1.0, d);
}

void vertex() {
	pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// abscisse du fragment sur le chemin de balayage (m)
	float s;
	if (balayage_mode == 1) {
		vec2 q = vec2(pos_monde.x - balayage_axe_xz.x, -(pos_monde.z - balayage_axe_xz.y));
		float a = (atan(q.y, q.x) - balayage_angle0) * balayage_sens;
		a -= TAU * floor((a + PI) / TAU); // ramené dans [-PI, PI) : la face est loin de la couture
		s = balayage_decalage + a * balayage_rayon;
	} else {
		s = balayage_decalage + (pos_monde.y - balayage_y0);
	}
	float v = s / max(balayage_longueur, 0.0001); // 0 = bas / départ, 1 = haut / fin de la surface

	// voile qui monte : centre de -w à 1+w pour partir et finir hors surface
	float c = mix(-band_width, 1.0 + band_width, progress);
	float band = bump(v, c, band_width);
	// l'ensemble s'éteint sur les 20 derniers % pour ne laisser aucune trace
	float fade = 1.0 - smoothstep(0.8, 1.0, progress);

	// relief : le voile accroche les arêtes de joints (même projection monde que la pierre)
	float relief = 0.0;
	if (edge_boost > 0.0) {
		vec3 dpx = dFdx(pos_monde);
		vec3 dpy = dFdy(pos_monde);
		vec2 uv_monde;
		vec2 dux;
		vec2 duy;
		if (proj_mode == 1) {
			vec2 qm = vec2(pos_monde.x - proj_axe_xz.x, -(pos_monde.z - proj_axe_xz.y));
			float k = proj_rayon_ref / proj_tuile_m;
			uv_monde = vec2(atan(qm.y, qm.x) * k, -pos_monde.y / proj_tuile_m);
			float r2 = max(dot(qm, qm), 1e-8);
			dux = vec2((qm.x * -dpx.z - qm.y * dpx.x) / r2 * k, -dpx.y / proj_tuile_m);
			duy = vec2((qm.x * -dpy.z - qm.y * dpy.x) / r2 * k, -dpy.y / proj_tuile_m);
		} else {
			uv_monde = vec2(dot(pos_monde, proj_axe_u), dot(pos_monde, proj_axe_v)) / proj_tuile_m;
			dux = vec2(dot(dpx, proj_axe_u), dot(dpx, proj_axe_v)) / proj_tuile_m;
			duy = vec2(dot(dpy, proj_axe_u), dot(dpy, proj_axe_v)) / proj_tuile_m;
		}
		vec3 n = textureGrad(normal_tex, uv_monde * uv_echelle, dux * uv_echelle, duy * uv_echelle).rgb * 2.0 - 1.0;
		relief = clamp(length(n.xy) * 2.5, 0.0, 1.0);
	}
	float k_total = band * fade * (1.0 + edge_boost * relief);
	ALBEDO = tint * peak * k_total;
}
