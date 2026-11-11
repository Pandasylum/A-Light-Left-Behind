shader_type spatial;
// Pierre nettoyable (spike P2-N1) : COPIE adaptée de tests/test_mousse/mousse.gdshader.
// - État par face, lu en UV2 : R = proprete_salete, G = proprete_mousse (0 = sale, 1 = propre).
// - Épaisseurs et textures lues en projection monde (uv_monde remplace UV partout).
//   Les uniforms proj_* sont écrits par SurfaceMapping.WorldProjection.apply_to(), qui sert
//   aussi à la lecture CPU (CleanableFace) : une seule source de paramètres.
// - Chaque couche : visible = smoothstep(S + epsilon, S + epsilon + douceur, épaisseur).

instance uniform vec3 teinte : source_color = vec3(1.0);

group_uniforms etat;
// Masque d'état de la face (RG8). Absent = noir = entièrement sale.
uniform sampler2D etat : hint_default_black, filter_linear, repeat_disable;
// PROVISOIRE, écrit par CleanableFace depuis CleaningParams (constante unique).
uniform float epsilon : hint_range(0.0, 0.5) = 0.05;
// Fin de geste : 0 = état tel quel, 1 = entièrement propre (animé par CleanableFace).
uniform float fondu : hint_range(0.0, 1.0) = 0.0;

group_uniforms projection;
uniform int proj_mode = 0; // 0 = plan, 1 = cylindre d'axe vertical
uniform vec3 proj_axe_u = vec3(1.0, 0.0, 0.0);
uniform vec3 proj_axe_v = vec3(0.0, 0.0, 1.0);
uniform vec2 proj_axe_xz = vec2(0.0);
uniform float proj_rayon_ref = 1.0;
uniform float proj_tuile_m = 1.0;

group_uniforms propre;
uniform sampler2D albedo_propre : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_propre : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_propre : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float rugosite_propre : hint_range(0.0, 1.0) = 1.0;
uniform float force_normal : hint_range(0.0, 2.0) = 1.0;
uniform float metal : hint_range(0.0, 1.0) = 0.0;

group_uniforms sale;
uniform sampler2D albedo_sale : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_sale : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 couleur_sale : source_color = vec3(1.0);
uniform float rugosite_sale : hint_range(0.0, 1.0) = 1.0;

group_uniforms transition;
// Épaisseur de la saleté. Sans mipmap : parité avec la lecture CPU au niveau 0.
uniform sampler2D masque_salete : hint_default_white, filter_linear, repeat_enable;
uniform float douceur : hint_range(0.005, 0.5) = 0.05;
// Échelle des deux masques d'épaisseur, en répétitions par unité de uv_monde (lue aussi par le CPU).
uniform vec2 echelle_epaisseur = vec2(1.0);

group_uniforms poussiere;
uniform float poussiere_quantite : hint_range(0.0, 1.0) = 0.25;
uniform vec3 poussiere_couleur : source_color = vec3(0.55, 0.52, 0.47);

group_uniforms couche_mousse;
uniform sampler2D albedo_mousse : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_mousse : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Épaisseur de la mousse (0 = aucune). Les zones fines partent en premier, le cœur en dernier.
uniform sampler2D masque_mousse : hint_default_black, filter_linear, repeat_enable;
uniform sampler2D roughness_mousse : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 echelle_mousse = vec2(1.0);
uniform float douceur_mousse : hint_range(0.005, 0.5) = 0.25;
uniform float rugosite_mousse : hint_range(0.0, 2.0) = 1.2; // multiplie la texture
uniform float force_normal_mousse : hint_range(0.0, 3.0) = 1.0;

group_uniforms;
uniform vec2 uv_echelle = vec2(1.0);

varying vec3 normale_monde;
varying vec3 pos_monde;

void vertex() {
	normale_monde = MODEL_NORMAL_MATRIX * NORMAL;
	pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// --- Projection monde (même formule que SurfaceMapping.WorldProjection.uv_monde) ---
	vec3 dpx = dFdx(pos_monde);
	vec3 dpy = dFdy(pos_monde);
	vec2 uv_monde;
	vec2 dux; // dérivées d'écran de uv_monde, continues à la couture de l'angle
	vec2 duy;
	if (proj_mode == 1) {
		vec2 q = vec2(pos_monde.x - proj_axe_xz.x, -(pos_monde.z - proj_axe_xz.y));
		float k = proj_rayon_ref / proj_tuile_m;
		uv_monde = vec2(atan(q.y, q.x) * k, -pos_monde.y / proj_tuile_m); // v vers le bas, comme la texture
		float r2 = max(dot(q, q), 1e-8);
		dux = vec2((q.x * -dpx.z - q.y * dpx.x) / r2 * k, -dpx.y / proj_tuile_m);
		duy = vec2((q.x * -dpy.z - q.y * dpy.x) / r2 * k, -dpy.y / proj_tuile_m);
	} else {
		uv_monde = vec2(dot(pos_monde, proj_axe_u), dot(pos_monde, proj_axe_v)) / proj_tuile_m;
		dux = vec2(dot(dpx, proj_axe_u), dot(dpx, proj_axe_v)) / proj_tuile_m;
		duy = vec2(dot(dpy, proj_axe_u), dot(dpy, proj_axe_v)) / proj_tuile_m;
	}

	vec2 uv = uv_monde * uv_echelle;
	vec2 uv_dx = dux * uv_echelle;
	vec2 uv_dy = duy * uv_echelle;
	vec2 uvm = uv_monde * echelle_mousse;
	vec2 uvm_dx = dux * echelle_mousse;
	vec2 uvm_dy = duy * echelle_mousse;
	vec2 uve = uv_monde * echelle_epaisseur;

	// --- État de la face (UV2), fondu de fin de geste ---
	vec2 etat_propre = mix(texture(etat, UV2).rg, vec2(1.0), fondu);

	// --- Saleté ---
	float d = max(douceur, 0.005);
	float e_salete = textureLod(masque_salete, uve, 0.0).r;
	float net = 1.0 - smoothstep(etat_propre.r + epsilon, etat_propre.r + epsilon + d, e_salete);

	vec3 alb_propre = textureGrad(albedo_propre, uv, uv_dx, uv_dy).rgb;
	vec3 alb_sale = textureGrad(albedo_sale, uv, uv_dx, uv_dy).rgb * couleur_sale;
	float rug_propre = textureGrad(roughness_propre, uv, uv_dx, uv_dy).r * rugosite_propre;
	float rug_sale = textureGrad(roughness_sale, uv, uv_dx, uv_dy).r * rugosite_sale;

	float haut = smoothstep(0.5, 0.9, normalize(normale_monde).y);
	float p = haut * poussiere_quantite * (1.0 - net);
	alb_sale = mix(alb_sale, poussiere_couleur, p);
	rug_sale = mix(rug_sale, 1.0, p);

	vec3 alb = mix(alb_sale, alb_propre, net);
	float rug = mix(rug_sale, rug_propre, net);

	// --- Mousse : même règle que la saleté ---
	float dm = max(douceur_mousse, 0.005);
	float e_mousse = textureLod(masque_mousse, uve, 0.0).r;
	float vis = smoothstep(etat_propre.g + epsilon, etat_propre.g + epsilon + dm, e_mousse);

	alb = mix(alb, textureGrad(albedo_mousse, uvm, uvm_dx, uvm_dy).rgb, vis);
	rug = mix(rug, clamp(textureGrad(roughness_mousse, uvm, uvm_dx, uvm_dy).r * rugosite_mousse, 0.0, 1.0), vis);

	// --- Normale : repère tangent par dérivées d'écran de uv_monde (les .glb n'ont pas de tangentes) ---
	vec2 ns = textureGrad(normal_propre, uv, uv_dx, uv_dy).rg * 2.0 - 1.0;
	vec2 nm = textureGrad(normal_mousse, uvm, uvm_dx, uvm_dy).rg * 2.0 - 1.0;
	float ns_z = sqrt(max(0.0, 1.0 - dot(ns, ns)));
	vec2 xy = ns * (1.0 - 0.7 * vis) + nm * force_normal_mousse * vis;
	vec3 n = normalize(vec3(xy, ns_z));

	vec3 n_vue = normalize(NORMAL);
	vec3 dvx = dFdx(VERTEX);
	vec3 dvy = dFdy(VERTEX);
	vec3 dvy_perp = cross(dvy, n_vue);
	vec3 dvx_perp = cross(n_vue, dvx);
	float sens = dot(dvx, dvy_perp) < 0.0 ? -1.0 : 1.0;
	vec3 t = (dvy_perp * dux.x + dvx_perp * duy.x) * sens; // sens de u croissant
	vec3 b = (dvy_perp * dux.y + dvx_perp * duy.y) * sens; // sens de v croissant
	float lt = dot(t, t);
	float lb = dot(b, b);
	if (lt > 1e-20 && lb > 1e-20) {
		t *= inversesqrt(lt);
		b *= inversesqrt(lb);
		// Convention Godot : binormale = sens de v décroissant.
		vec3 perturbee = t * n.x - b * n.y + n_vue * n.z;
		NORMAL = normalize(mix(n_vue, perturbee, force_normal));
	}

	ALBEDO = alb * teinte;
	ROUGHNESS = rug;
	METALLIC = metal * net * (1.0 - vis);
}
