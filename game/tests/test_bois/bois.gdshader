shader_type spatial;
// BOIS : propre <-> sale, avec deux canaux de saleté indépendants.
//   1) POUSSIÈRE : voile mat qui éclaircit, désature et éteint les reflets.
//   2) TRACES    : marques sombres (frottements, empreintes, coulures), lues en contraste de valeur.
// Pas de mousse, pas de géométrie dédiée : le relief vient de la normal map seule.
//
// MODE D'EMPLOI (5 lignes)
// 1. Mesh : n'importe lequel avec un UV2 (primitives Godot : cocher « Add UV2 » ; import : « Light Baking = Static Lightmaps »).
// 2. Matériau : ShaderMaterial avec ce shader ; glisser albédo, normale (OpenGL), rugosité, masque d'état et bruit tuilable.
// 3. Masque d'état (lu en UV2) : R = ordre de nettoyage (sombre = part en premier), V = épaisseur de poussière
//    (avec un léger rebord le long d'un côté de chaque trace), B = traces (opacité variable, un bord net, un bord fondu).
// 4. Par objet (Inspecteur > GeometryInstance3D > Instance Shader Parameters, ou set_instance_shader_parameter) :
//    proprete (0 sale -> 1 propre, efface tout), poussiere et traces (1 = canal complet, 0 = canal nettoyé).
// 5. Si c'est illisible : monter « Poussiere plafond » / baisser « Traces contraste » ; si le voile brûle : baisser « Poussiere plafond » ;
//    si les bords sont trop nets : monter « Bruit force » ; si le bois nu brille comme du métal : monter « Rugosite bois ».

// ---- État, par objet (chaque planche a ses propres valeurs, un seul matériau partagé) ----
// 0.0 = entièrement sale, 1.0 = entièrement propre (efface poussière ET traces).
instance uniform float proprete : hint_range(0.0, 1.0) = 0.0;
// 1.0 = voile de poussière complet, 0.0 = poussière entièrement essuyée.
instance uniform float poussiere : hint_range(0.0, 1.0) = 1.0;
// 1.0 = toutes les traces, 0.0 = traces entièrement frottées.
instance uniform float traces : hint_range(0.0, 1.0) = 1.0;
instance uniform vec3 teinte : source_color = vec3(1.0);

group_uniforms bois;
// Base : Planks037A (CC0, ambientCG), albédo nettoyé « bois_alb_propre ». Normale au format OpenGL (fichier « NormalGL »).
uniform sampler2D albedo_bois : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_bois : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_bois : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
// Multiplie la texture. Planks037A est lisse (≈ 0,45 en moyenne) : à 1.0 le bois nu renvoie une plage brillante sous la lumière.
uniform float rugosite_bois : hint_range(0.0, 2.0) = 1.8;
uniform float force_normal : hint_range(0.0, 2.0) = 1.0;
uniform vec2 uv_echelle = vec2(1.0); // répétition de la texture de bois

group_uniforms etat;
// Masque d'état, lu en UV2 (jamais répété). R = ordre de nettoyage, V = poussière, B = traces.
uniform sampler2D masque_etat : hint_default_white, filter_linear_mipmap, repeat_disable;
// Largeur du fondu entre propre et sale quand « proprete » avance.
uniform float douceur : hint_range(0.005, 0.5) = 0.08;

group_uniforms bruit_bords;
// Bruit tuilable en niveaux de gris : il grignote les bords du masque pour qu'ils ne soient jamais nets.
uniform sampler2D bruit : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float bruit_echelle : hint_range(0.5, 16.0) = 3.0; // répétitions du bruit sur l'objet
uniform float bruit_force : hint_range(0.0, 1.0) = 0.5; // 0 = bords du masque tels quels

group_uniforms canal_poussiere;
// Gris neutre légèrement chaud : aucune dominante bleue propre, seule la lumière teinte le voile.
uniform vec3 poussiere_couleur : source_color = vec3(0.60, 0.56, 0.50);
uniform float poussiere_eclaircit : hint_range(0.0, 1.0) = 1.0; // part de couleur de poussière dans le voile
// Plafond : gain de valeur maximal du voile par rapport au bois nu (0 = n'éclaircit jamais, 1 = pas de plafond).
uniform float poussiere_plafond : hint_range(0.0, 1.0) = 0.25;
// Perte de couleur du bois sous le voile. Le bois tend vers la teinte de la poussière, jamais vers un gris pur.
uniform float poussiere_desature : hint_range(0.0, 1.0) = 0.7;
uniform float poussiere_matite : hint_range(0.0, 1.0) = 1.0; // 1 = plus aucun reflet sous la poussière
// Épaisseur de voile à partir de laquelle le reflet est éteint : bas = même un reste de voile est mat (pas de reflet laiteux).
uniform float poussiere_seuil_mat : hint_range(0.01, 1.0) = 0.25;
uniform float poussiere_aplatit : hint_range(0.0, 1.0) = 0.35; // la poussière comble un peu le relief
uniform float douceur_poussiere : hint_range(0.005, 0.5) = 0.3; // fondu quand « poussiere » baisse

group_uniforms canal_traces;
uniform vec3 traces_couleur : source_color = vec3(0.30, 0.25, 0.22); // multiplie le bois : plus sombre = plus lisible
uniform float traces_force : hint_range(0.0, 1.0) = 1.0;
// Courbe du masque de traces : < 1 renforce les zones légères (lisibilité sans voile), 1 = masque tel quel.
uniform float traces_contraste : hint_range(0.3, 2.0) = 0.5;
uniform float traces_rugosite : hint_range(0.0, 1.0) = 0.75; // rugosité minimale dans les traces
uniform float traces_percent_poussiere : hint_range(0.0, 1.0) = 0.8; // 1 = les traces trouent le voile de poussière
uniform float douceur_traces : hint_range(0.005, 0.5) = 0.2; // fondu quand « traces » baisse

void fragment() {
	vec2 uv = UV * uv_echelle;

	// --- Masque d'état (UV2) et bruit de bord ---
	vec3 etat = texture(masque_etat, UV2).rgb;
	float b = (texture(bruit, UV2 * bruit_echelle).r - 0.5) * 2.0 * bruit_force; // -force .. +force

	// Nettoyage global : les zones sombres du canal R partent en premier.
	float d = max(douceur, 0.005);
	float ordre = clamp(etat.r + b * 0.25, 0.0, 1.0);
	float net = smoothstep(ordre, ordre + d, proprete * (1.0 + d)); // 0 = sale, 1 = propre
	float sale = 1.0 - net;

	// Canal TRACES : le bruit multiplie le masque, donc il ne crée jamais de trace là où il n'y en a pas.
	float dt = max(douceur_traces, 0.005);
	float t = clamp(etat.b * (1.0 + b), 0.0, 1.0);
	float seuil_t = (1.0 - traces) * (1.0 + dt);
	float marque = smoothstep(seuil_t - dt, seuil_t, t) * pow(t, traces_contraste) * sale * traces_force;

	// Canal POUSSIÈRE : les zones fines du canal V partent en premier.
	float dp = max(douceur_poussiere, 0.005);
	float p = clamp(etat.g * (1.0 + b), 0.0, 1.0);
	float seuil_p = (1.0 - poussiere) * (1.0 + dp);
	float voile = smoothstep(seuil_p - dp, seuil_p, p) * p * sale; // voile proportionnel à l'épaisseur
	voile *= 1.0 - marque * traces_percent_poussiere; // un doigt passé dans la poussière laisse le bois à nu

	// --- Couleur ---
	vec3 alb = texture(albedo_bois, uv).rgb;
	float valeur = dot(alb, vec3(0.2126, 0.7152, 0.0722));
	vec3 lum = vec3(0.2126, 0.7152, 0.0722);
	vec3 ton_poussiere = poussiere_couleur / max(dot(poussiere_couleur, lum), 0.001); // teinte seule, valeur 1
	vec3 alb_voile = mix(alb, valeur * ton_poussiere, poussiere_desature); // désature vers le ton de la poussière
	alb_voile = mix(alb_voile, poussiere_couleur, poussiere_eclaircit); // éclaircit
	// Plafond : le voile ne dépasse jamais la valeur du bois nu + « poussiere_plafond » (pas de blanc brûlé).
	alb_voile *= min(1.0, (valeur + poussiere_plafond) / max(dot(alb_voile, lum), 0.001));
	alb = mix(alb, alb_voile, voile);
	alb = mix(alb, alb * traces_couleur, marque); // assombrit : contraste de valeur

	// --- Reflets ---
	float rug = clamp(texture(roughness_bois, uv).r * rugosite_bois, 0.0, 1.0);
	rug = mix(rug, max(rug, traces_rugosite), marque); // une trace ne brille jamais plus que le bois nu
	float mat = smoothstep(0.0, poussiere_seuil_mat, voile) * poussiere_matite;
	rug = mix(rug, 1.0, mat);

	ALBEDO = alb * teinte;
	ROUGHNESS = rug;
	SPECULAR = 0.5 * (1.0 - mat);
	METALLIC = 0.0;
	NORMAL_MAP = texture(normal_bois, uv).rgb;
	NORMAL_MAP_DEPTH = force_normal * (1.0 - voile * poussiere_aplatit);
}
