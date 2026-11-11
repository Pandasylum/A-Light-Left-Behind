shader_type spatial;
// Sale -> propre. Un seul matériau partagé ; l'état vit dans l'instance (proprete).

// État par objet : 0.0 = entièrement sale, 1.0 = entièrement propre.
instance uniform float proprete : hint_range(0.0, 1.0) = 0.0;
// Teinte par objet (blanc = aucune variation).
instance uniform vec3 teinte : source_color = vec3(1.0);

group_uniforms propre;
uniform sampler2D albedo_propre : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_propre : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_propre : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float rugosite_propre : hint_range(0.0, 1.0) = 0.25; // multiplie la texture
uniform float force_normal : hint_range(0.0, 2.0) = 1.0;
uniform float metal : hint_range(0.0, 1.0) = 0.0;

group_uniforms sale;
uniform sampler2D albedo_sale : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_sale : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 couleur_sale : source_color = vec3(0.42, 0.37, 0.30); // multiplie albedo_sale
uniform float rugosite_sale : hint_range(0.0, 1.0) = 0.95; // multiplie la texture

group_uniforms transition;
// Canal rouge : les zones sombres se nettoient en premier. Lu sur l'UV non répété.
uniform sampler2D masque_salete : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float douceur : hint_range(0.005, 0.5) = 0.05; // petit = bord net

group_uniforms poussiere;
uniform float poussiere_quantite : hint_range(0.0, 1.0) = 0.3; // 0 = désactivée
uniform vec3 poussiere_couleur : source_color = vec3(0.55, 0.52, 0.47);

group_uniforms;
uniform vec2 uv_echelle = vec2(1.0); // répétition des textures (pas du masque)

varying vec3 normale_monde;

void vertex() {
	// Normale géométrique en espace monde : stable, indépendante de la caméra.
	normale_monde = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec2 uv = UV * uv_echelle;
	float d = max(douceur, 0.005);

	// 0 = sale, 1 = propre. Garantit tout sale à proprete=0 et tout propre à 1.
	float m = texture(masque_salete, UV).r;
	float net = smoothstep(m, m + d, proprete * (1.0 + d));

	vec3 alb_propre = texture(albedo_propre, uv).rgb;
	vec3 alb_sale = texture(albedo_sale, uv).rgb * couleur_sale;
	float rug_propre = texture(roughness_propre, uv).r * rugosite_propre;
	float rug_sale = texture(roughness_sale, uv).r * rugosite_sale;

	// Poussière : faces tournées vers le haut, seulement là où c'est encore sale.
	float haut = smoothstep(0.5, 0.9, normalize(normale_monde).y);
	float p = haut * poussiere_quantite * (1.0 - net);
	alb_sale = mix(alb_sale, poussiere_couleur, p);
	rug_sale = mix(rug_sale, 1.0, p);

	ALBEDO = mix(alb_sale, alb_propre, net) * teinte;
	ROUGHNESS = mix(rug_sale, rug_propre, net);
	METALLIC = metal * net; // la crasse masque le métal
	NORMAL_MAP = texture(normal_propre, uv).rgb;
	NORMAL_MAP_DEPTH = force_normal;
}
