shader_type spatial;
// Sale -> propre + couche de mousse. L'état vit dans l'instance (proprete, mousse).

// 0.0 = entièrement sale, 1.0 = entièrement propre.
instance uniform float proprete : hint_range(0.0, 1.0) = 0.0;
// 1.0 = mousse complète, 0.0 = mousse entièrement nettoyée.
instance uniform float mousse : hint_range(0.0, 1.0) = 1.0;
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

	// Couche de mousse : visible là où l'épaisseur dépasse le seuil (1 - mousse).
	float dm = max(douceur_mousse, 0.005);
	float c = texture(masque_mousse, UV).r;
	float vis = smoothstep(1.0 - mousse, 1.0 - mousse + dm, c) * step(0.002, c);

	vec2 uvm = UV * echelle_mousse;
	alb = mix(alb, texture(albedo_mousse, uvm).rgb, vis);
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
