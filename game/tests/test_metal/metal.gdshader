shader_type spatial;
// MÉTAL PEINT : propre <-> rouillé, un seul canal ROUILLE (même logique que bois.gdshader).
// La rouille grandit par seuil : la texture « croissance » dit quelles zones rouillent en premier,
// le masque d'état (UV2, canal V) dit OÙ elle démarre (joints entre panneaux, bords).
// Le métal est de la peinture : METALLIC = 0, rugosité plancher pour qu'aucun reflet ne brûle.
//
// MODE D'EMPLOI
// 1. Mesh avec UV2 (primitives : « Add UV2 » ; import : « Light Baking = Static Lightmaps »).
// 2. Par objet (Instance Shader Parameters / set_instance_shader_parameter) :
//    rouille 0 -> 1 (0 = propre, 0.5 = moitié de la surface, 1 = rouille complète).
// 3. Si les reflets brûlent : monter « Rugosite plancher ». Si la rouille n'est pas liée aux joints : monter « Localisation ».
// 4. « Rugosite brute » = rugosité d'origine de Metal055B (trop brillante) : sert seulement à comparer.

instance uniform float rouille : hint_range(0.0, 1.0) = 0.0;
instance uniform vec3 teinte : source_color = vec3(1.0);

group_uniforms metal;
// Bases : Metal055B (propre, rouille retirée) et Metal056C (rouille), CC0 ambientCG, albédos peints niveau 2.
uniform sampler2D albedo_propre : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D albedo_rouille : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rug_propre : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rug_rouille : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rug_brute : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_propre : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_rouille : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool rugosite_brute = false;
// Filet de sécurité : la rugosité propre n'est jamais en dessous (la texture livrée est déjà à 0,45-0,60).
uniform float rugosite_plancher : hint_range(0.0, 1.0) = 0.42;
uniform float force_normal : hint_range(0.0, 2.0) = 1.0;
uniform vec2 uv_echelle = vec2(1.0);

group_uniforms etat;
// UV2, jamais répété. V = localisation de la rouille (1 = joint ou bord : rouille en premier).
uniform sampler2D masque_etat : hint_default_white, filter_linear_mipmap, repeat_disable;
// Croissance : 0 = rouille en premier, 1 = en dernier. Alignée sur l'albédo (même UV).
uniform sampler2D croissance : hint_default_black, filter_linear_mipmap, repeat_enable;
// 0 = rouille uniforme, 1 = à mi-course les joints sont rouillés et les panneaux propres.
uniform float localisation : hint_range(0.0, 1.0) = 0.8;
uniform float douceur : hint_range(0.005, 0.5) = 0.06;

void fragment() {
	vec2 uv = UV * uv_echelle;
	float loc = texture(masque_etat, UV2).g;

	// Avancée locale : décalée par la localisation, mais toujours 0 à rouille = 0 et 1 à rouille = 1.
	float s = clamp(rouille + localisation * (loc - 0.5) * 2.0 * min(rouille, 1.0 - rouille), 0.0, 1.0);
	float d = max(douceur, 0.005);
	float seuil = texture(croissance, uv).r;
	float m = smoothstep(seuil, seuil + d, s * (1.0 + d)); // 1 = rouillé

	vec3 alb = mix(texture(albedo_propre, uv).rgb, texture(albedo_rouille, uv).rgb, m);

	float rug_p = rugosite_brute ? texture(rug_brute, uv).r : max(texture(rug_propre, uv).r, rugosite_plancher);
	float rug = mix(rug_p, texture(rug_rouille, uv).r, m);

	ALBEDO = alb * teinte;
	ROUGHNESS = clamp(rug, 0.0, 1.0);
	SPECULAR = 0.5;
	METALLIC = 0.0;
	NORMAL_MAP = mix(texture(normal_propre, uv).rgb, texture(normal_rouille, uv).rgb, m);
	NORMAL_MAP_DEPTH = force_normal;
}
