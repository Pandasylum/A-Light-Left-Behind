shader_type spatial;
// Sale -> propre + couche de mousse + canal COULURES D'EAU (indépendant).
// L'état vit dans l'instance : proprete, mousse, coulures.
// COULURES : filets sombres qui descendent des joints et des plaques de mousse (masque_coulures, lu en UV comme la mousse).
//   Elles disparaissent avec la pierre sale (proprete) ; le paramètre coulures (1 -> 0) les efface une à une.
//   Superposition : la mousse épaisse les recouvre, la mousse fine les laisse transparaître (coulures_sur_mousse).
//   Rugosité et normale ne bougent pas dans une coulure : aucun risque de reflet brûlé en plus.

// 0.0 = entièrement sale, 1.0 = entièrement propre.
instance uniform float proprete : hint_range(0.0, 1.0) = 0.0;
// 1.0 = mousse complète, 0.0 = mousse entièrement nettoyée.
instance uniform float mousse : hint_range(0.0, 1.0) = 1.0;
// 1.0 = toutes les coulures, 0.0 = coulures entièrement effacées.
instance uniform float coulures : hint_range(0.0, 1.0) = 1.0;
instance uniform vec3 teinte : source_color = vec3(1.0);

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
uniform sampler2D masque_salete : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float douceur : hint_range(0.005, 0.5) = 0.05;

group_uniforms poussiere;
uniform float poussiere_quantite : hint_range(0.0, 1.0) = 0.25;
uniform vec3 poussiere_couleur : source_color = vec3(0.55, 0.52, 0.47);

group_uniforms couche_mousse;
uniform sampler2D albedo_mousse : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_mousse : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Épaisseur de la mousse (0 = aucune). Les zones fines partent en premier, le cœur en dernier.
uniform sampler2D masque_mousse : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D roughness_mousse : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 echelle_mousse = vec2(1.0, 0.5); // texture de mousse carrée : une répétition = 4 m sur le plan 4x2
uniform float douceur_mousse : hint_range(0.005, 0.5) = 0.25;
uniform float rugosite_mousse : hint_range(0.0, 2.0) = 1.2; // multiplie la texture
uniform float force_normal_mousse : hint_range(0.0, 3.0) = 1.0;

group_uniforms canal_coulures;
// Épaisseur/intensité des coulures (0 = aucune). Les filets les plus faibles partent en premier.
uniform sampler2D masque_coulures : hint_default_black, filter_linear_mipmap, repeat_disable;
// Multiplie l'albédo de la pierre sale. < 1 assombrit (coulure d'eau), > 1 éclaircit (dépôt calcaire) : variante à tester.
uniform vec3 coulures_facteur = vec3(0.13, 0.126, 0.122); // 2026-11-12 : ×0,16 retenu, ×0,13 pour compenser le masque v2 (à vérifier)
uniform float coulures_force : hint_range(0.0, 1.0) = 1.0;
// Courbe du masque : < 1 renforce les filets faibles (lisibilité), 1 = masque tel quel.
uniform float coulures_contraste : hint_range(0.3, 2.0) = 0.35;
uniform float douceur_coulures : hint_range(0.005, 0.5) = 0.4;
// Opacité minimale d'une coulure quand le curseur « coulures » approche de 0 : elle s'estompe au lieu de se réduire à son cœur noir.
uniform float coulures_estompe : hint_range(0.0, 1.0) = 0.6;
// Part de la coulure qui reste visible dans une mousse FINE (la mousse épaisse la cache toujours).
uniform float coulures_sur_mousse : hint_range(0.0, 1.0) = 0.35;

group_uniforms;
uniform vec2 uv_echelle = vec2(1.0);

varying vec3 normale_monde;

void vertex() {
	normale_monde = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec2 uv = UV * uv_echelle;
	float d = max(douceur, 0.005);

	float m = texture(masque_salete, UV).r;
	float net = smoothstep(m, m + d, proprete * (1.0 + d));

	vec3 alb_propre = texture(albedo_propre, uv).rgb;
	vec3 alb_sale = texture(albedo_sale, uv).rgb * couleur_sale;
	float rug_propre = texture(roughness_propre, uv).r * rugosite_propre;
	float rug_sale = texture(roughness_sale, uv).r * rugosite_sale;

	float haut = smoothstep(0.5, 0.9, normalize(normale_monde).y);
	float p = haut * poussiere_quantite * (1.0 - net);
	alb_sale = mix(alb_sale, poussiere_couleur, p);
	rug_sale = mix(rug_sale, 1.0, p);

	vec3 alb = mix(alb_sale, alb_propre, net);
	float rug = mix(rug_sale, rug_propre, net);

	// Canal COULURES : porté par la pierre sale, effacé avec elle ; indépendant de la mousse.
	float dc = max(douceur_coulures, 0.005);
	float tc = texture(masque_coulures, UV).r;
	float seuil_c = (1.0 - coulures) * (1.0 + dc);
	float marque = smoothstep(seuil_c - dc, seuil_c, tc) * pow(tc, coulures_contraste) * (1.0 - net) * coulures_force * mix(coulures_estompe, 1.0, coulures);
	alb = mix(alb, alb * coulures_facteur, marque);

	// Couche de mousse : visible là où l'épaisseur dépasse le seuil (1 - mousse).
	float dm = max(douceur_mousse, 0.005);
	float c = texture(masque_mousse, UV).r;
	float vis = smoothstep(1.0 - mousse, 1.0 - mousse + dm, c) * step(0.002, c);

	vec2 uvm = UV * echelle_mousse;
	// La mousse épaisse (c -> 1) cache la coulure ; la mousse fine la laisse passer (mousse mouillée, plus sombre).
	float marque_m = marque * coulures_sur_mousse * (1.0 - c);
	vec3 alb_mousse = texture(albedo_mousse, uvm).rgb * mix(vec3(1.0), coulures_facteur, marque_m);
	alb = mix(alb, alb_mousse, vis);
	rug = mix(rug, clamp(texture(roughness_mousse, uvm).r * rugosite_mousse, 0.0, 1.0), vis);

	vec3 ns = texture(normal_propre, uv).rgb * 2.0 - 1.0;
	vec3 nm = texture(normal_mousse, uvm).rgb * 2.0 - 1.0;
	vec2 xy = ns.xy * (1.0 - 0.7 * vis) + nm.xy * force_normal_mousse * vis;
	vec3 n = normalize(vec3(xy, ns.z));

	ALBEDO = alb * teinte;
	ROUGHNESS = rug;
	METALLIC = metal * net * (1.0 - vis);
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = force_normal;
}
