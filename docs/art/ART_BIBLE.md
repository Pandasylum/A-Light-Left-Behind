# ART BIBLE — A Light Left Behind

Propriétaire : projet Art Direction & Assets. Dernière mise à jour : 2026-11-12 (seuil du fût).
Statut : direction de travail NON OFFICIELLE jusqu'au test de style.
Légende : ✅ validé · 🟡 à décider

## Direction de travail 🟡
- Stylisé peint à la main avec éclairage réaliste.
- Critère de réussite : l'ambiance des références est respectée (jugement du développeur).
- Simplifié : formes épaisses, bords adoucis, textures peintes, peu de détail fin, palette limitée.
- Reste réaliste : intérieur froid à l'état abandonné, lumière plus chaude avec la restauration, lumière froide aux fenêtres, ombres douces, poussière, brume, pluie.
- Palette indicative : bois chaud, bleu patiné, rouille, pierre froide (valeurs à fixer).
- Le contraste sale / propre doit rester lisible (boucle de nettoyage).

## Références
Dossier : `docs/art/references/` (images à déposer par le développeur).
- 01 atelier : ambiance et matériaux seulement (image générée par IA, objets non fiables).
- 02 salle de la lanterne : matériaux et verticalité. Plein soleil, alors que l'ambiance initiale visée est froide, pluvieuse et venteuse.
- 03 escalier de bois : verticalité, circulation entre les pièces.

## Test de style 🟡
- Objets : une chaise, une caisse, un outil.
- Deux générateurs 3D comparés (candidats : Tripo, Meshy, Rodin), sans abonnement avant le choix.
- Intégration dans Godot sous une lampe chaude et une fenêtre froide, comparaison aux références.
- 🟡 Rendre les mêmes objets sous lumière froide seule (état de départ), puis sous lumière réchauffée (après restauration).

## Principes de production
- Ressources existantes et bibliothèques d'abord (vérifier les licences commerciales).
- Murs, sols, plafonds : modules réutilisables. Génération 3D par IA réservée aux meubles et petits objets. Jamais une pièce entière en un seul modèle.
- Tout modèle généré est vérifié dans Blender (échelle, topologie, UV, matériaux, collisions), puis dans Godot.

## À décider 🟡
Outil 3D principal, format d'export, budget de polygones, résolution des textures, palette finale.

## Palette et matériaux

Statut : seul le principe général est validé. Le reste est une proposition 🟡, à valider après le test de style.

### Principe ✅ (2026-11-10)
- Palette commune à tout le phare, variations par pièce.
- Lumière froide et bleutée au début, plus chaude avec la restauration.

### Ambiance initiale ✅ (2026-11-10)
- Tout l'intérieur est teinté de froid (matériaux, lumière, étalonnage) : ambiance pesante par la teinte et la lumière.
- La luminosité n'est pas abaissée : le contraste de valeur reste suffisant pour lire la saleté.
- Le froid passe par l'éclairage et l'étalonnage (Godot), pas par les textures, qui restent neutres et désaturées.

### Palette commune 🟡
- Bois : brun vieilli, délavé, sombre.
- Métal : fer noirci, cuivre terni, acier rouillé.
- Murs : pierre grise, enduit jauni, peinture écaillée.
- Textiles désaturés : beige, brun, vert passé.
- Valeurs hexadécimales à fixer après le test de style. En attendant, référence : PROJECT_RULES §4.3.

### Variantes par espace 🟡
La liste et les noms des pièces relèvent du GDD (§6, graphe non figé). Ici, seulement des familles de matériaux.
- Hall central : pierre, bois, métal, ambiance froide.
- Cuisine : carrelage, surfaces lavables, faïence.
- Salon : bois, textiles, mobilier ancien.
- Atelier : bois brut, métal, outils, étagères.
- Chambre : bois sombre, tissus, effets personnels.
- Archives : bois, papier jauni, étagères, poussière.
- Lanterne : métal, verre, mécanismes, lumière.
- Vestibule d'entrée (tutoriel) : à définir.

### États selon la progression 🟡
- Avant : couleurs ternes, poussière, humidité, éclairage froid, contraste de teinte faible.
- Après : bois retrouvé, surfaces propres, textiles restaurés, lumière plus chaude.

### Règles de production 🟡
- Mêmes matériaux sur plusieurs pièces.
- Varier meubles et décorations plutôt que les modèles.
- Textures et variations de couleur plutôt que modèles différents.
- Éclairage et état des matériaux évoluent avec la progression.
- Cohérence architecturale dans tout le phare.

### Matériaux de base à produire en premier 🟡
1. Bois vieilli (sombre ; variante brute pour l'atelier). 2. Pierre grise. 3. Enduit / peinture écaillée. 4. Fer noirci / acier rouillé (masque de rouille). 5. Cuivre / laiton terni. 6. Textile désaturé (teinte paramétrable).
Deuxième vague : carrelage / faïence, papier jauni, verre.

2026-11-11 : test technique. Le shader sale/propre à masque (Godot 4.6, Forward+) fonctionne sur un plan avec textures synthétiques. Style non validé.

2026-11-10 : Protocole de test de style validé. Scène : coin d’atelier, une caméra, 3 matériaux (bois, pierre, métal rouillé), 3 objets. 4 captures : froid/chaud × propre/sale. Le style « peint + éclairage réaliste » reste NON OFFICIEL jusqu’au verdict, rendu le 2026-11-12 (voir section 2026-11-12).

2026-11-11 : Style (validé par le développeur). « Stylisé réaliste » = textures photo simplifiées (niveau 2) + éclairage réaliste. « Peint à la main » est abandonné. Cohérent avec PROJECT_RULES §4.1. Condition : respecter l’ambiance des références (atelier en bois chaud, lanterne rouillée, escalier de bois dans une tour de pierre). Statut : OFFICIEL, validé le 2026-11-12 (test bois, voir section 2026-11-12).

2026-11-11 : Sens de « sale » par matériau. Pierre : humidité et mousse ; restaurée, elle devient plus sèche et plus claire. Bois : voile de poussière mate et traces. Métal : rouille. Le contraste de valeur reste suffisant pour lire la saleté. Pour le bois, la lisibilité passe par les signes (poussière, traces) en plus de la valeur.

2026-11-11 : Palette, mises à jour. En lumière chaude, la pierre rend gris-brun. Nouvelle ligne « mousse » : vert olive sombre, valeur de départ ≈ 
#313B12 (moyenne mesurée sur la texture Moss002 étalonnée), à ajuster.

2026-11-11 : Mousse sur pierre, test technique concluant. Couche séparée (albédo, rugosité et normale CC0 Moss002, niveau 2) pilotée par un masque d’épaisseur ; seuil par instance, les zones fines partent en premier. La pierre de base doit être sans mousse. La mousse est mate, la pierre sale est brillante (humide). Points ouverts : bords trop nets (à corriger dans le masque), relief et reflets photographiques sur la pierre sale, mousse contre traces et crasse non testée, mousse tenace non testée.

## Noyau de pierre : joints

- Deux niveaux de joints. Appareillage : discret, 6 mm de large, 3 mm de creux, assises de 0,26 m. Limite de panneau : 18 mm de large, 10 mm de creux, joint vertical tous les 90°, bandeau de 45 mm par anneau (90 mm à deux anneaux empilés). 🟡 valeurs de départ.
- Rendu en normal map et albédo assombri dans le joint. Pas de relief en géométrie : à 0,9 m, 10 mm réels ne se distinguent pas de la normal map.
- Appareillage en blocs de 30° avec demi-blocs de 15° en décalage, de sorte que les joints verticaux tombent sur les arêtes de facette.
- Critère : la limite de panneau reste lisible dans tous les états, y compris tout sale. Mousse atténuée d’environ 60 % sur ±30 mm autour des limites. 🟡
- Format : 2 400 × 1 650 px par anneau (≈ 764 px/m), tuile d’un tour × 1 anneau (3,1416 × 2,16 m), UV1 en mètres selon la Règle d’export §5 (échelle de matériau 1/3,1416 ; 1/2,16), origine sur une limite de panneau. Normal map OpenGL Y+ en linéaire, albédo en sRGB. Import en VRAM standard, sans HQ. Lecture en production par projection cylindrique monde : vérifiée dans Godot (essai 2026-11-12). 🟡
- La pierre procédurale du test est provisoire, en attendant la pierre peinte niveau 2.

## 2026-11-11 — Modules du fût : règle d'export et tuilage

Origine : demande Engineering (masque d'état par face en UV2, SurfaceMapping cylindre).
Validé Direction : escalier central hélicoïdal ; marche 1,5 m ; 24 marches par tour. Validé développeur : tuilage N = 12.
Statut : règle d'export validée pour les modules témoins. Style OFFICIEL depuis le 2026-11-12 (test bois validé, voir section 2026-11-12). Modules vérifiés dans les .glb par Engineering ; import Godot pas encore testé.

### Valeurs
- Rayon intérieur du fût R = 2,0 m. Noyau cylindrique R = 0,5 m. Largeur de marche 1,5 m.
- Tronçons de 15° (360 / 24). Arc du mur ≈ 0,524 m.
- PARAMÈTRES non figés (étage non décidé) : hauteur d'étage, marches par étage. Cible hauteur de marche 17–19 cm (0,18 m en test).
- Hauteurs PROVISOIRES : étage 4,32 m, module mur/noyau 2,16 m. Tout changement impose un nouvel export et le test de correspondance Engineering.

### Règle d'export
1. Mur et noyau : tronçons de cylindre, rayon unique, axe vertical, origine sur l'axe, angle de 0 à θ. Aucune déformation par module.
2. Marche : face de dessus plane (1 emplacement de matériau) + contremarche plane à l'angle 0 (1 emplacement). Marche k : rotation k·θ, hauteur k·h_marche.
3. Relief par normal map, jamais par géométrie.
4. Échelle : 1 unité = 1 m. Axe vertical : Z dans Blender, Y après export glTF.
5. UV1 (texture, mètres) : mur/noyau = développée linéaire (u = rayon × angle, v = hauteur) ; marche = plan (x, y).
6. UV2 (masque d'état) : un îlot 0..1 exact par face nettoyable, sans recouvrement. Mur : (angle/θ, hauteur/h). Marche dessus : (radial, angle/θ). Contremarche : (radial, hauteur/h). Faces non nettoyables : (0,0). Ne pas modifier les UV2.
7. Inversion de v (v = 1 − hauteur) : produite par l'export glTF, déjà prise en compte dans le code Godot. Ne pas la corriger dans Blender.
8. Un emplacement de matériau par face nettoyable ; le reste = « cache ». Ordre des primitives = ordre des emplacements.
9. Export glTF (.glb) : UV1 = UV, UV2 = TEXCOORD_1 (UV2 dans Godot).

### Tuilage (N = 12)
- Pierre et masque d'épaisseur lus en projection cylindrique monde, tuile = circonférence / N entier. Pas de décalage de u par instance.
- Mur (R = 2,0 m) : N = 12, tuile 1,047 m. Noyau (R = 0,5 m) : une tuile par tour (N = 1), soit 3,1416 m × 2,16 m, avec 4 panneaux de 90° par tuile. Décision Direction du 2026-11-12.
- Pierre et masque à produire tuilables à 1,047 m. Masque d'état basse résolution (≈ 64 px/m), bords adoucis par le shader (seuil + bruit tuilable).
- Motif visible toutes les ~1 m : variations peintes dans la pierre pour casser la répétition.
- Format : tuile d’Art = 1 tour × 1 module (3,1416 × 2,16 m, N = 1) ; u = angle/360 (0 = limite de panneau), v = hauteur/2,16 depuis le bas. Lecture par projection cylindrique monde, vérifiée dans Godot (essai 2026-11-12). Variante UV1 non retenue. 🟡
## 2026-11-12 — Style « stylisé réaliste » : test bois validé (style OFFICIEL)

Décision (validée développeur, 2026-11-12) : après le test bois (sale/propre, lumière froide/chaude, ensemble, gros plan, très gros plan, rasante, poussière 1 et 0,5), la direction « stylisé réaliste » devient officielle : textures photo simplifiées (peinture niveau 2) + éclairage réaliste. « Peint à la main » reste abandonné. La condition posée le 2026-11-11 (test bois à faire) est levée.

### Bois
- Base : Planks037A (CC0, ambientCG), version propre bois_alb_propre.jpg : taches grises retirées, éclaircie, réchauffée, veinage conservé. Script : build_bois_propre.py.
- « Sale » = voile de poussière mat + traces. Deux canaux indépendants (shader bois.gdshader), masque d'état en UV2, paramètres d'instance proprete, poussiere, traces.
- Voile : gris neutre légèrement chaud, sans dominante propre ; seule la lumière le teinte (bleuté sous lumière froide, beige sous lumière chaude).
- Traces : marques sombres, opacité variable, bord net d'un côté et fondu de l'autre. Lisibles à l'ensemble, sans zoomer.
- Nettoyage : la poussière part par plaques aux bords doux ; une trace disparaît avec la poussière qui la porte.
- Valeurs retenues (point de départ, ajustables) : poussiere_plafond 0,25 ; traces_contraste 0,5 ; poussiere_eclaircit 1,0 ; traces_force 1,0 ; rugosite_bois 1,8 (bois nu mat, jamais plus brillant que la référence) ; traces_rugosite en plancher (une trace ne brille jamais plus que le bois nu).

### Rappel des règles de lisibilité (déjà validées le 2026-11-11)
- Pierre : sale = humidité + mousse (propre : plus sèche, plus claire). Palette gris-brun en lumière chaude ; ligne de mousse vert olive sombre, départ ≈ #313B12.
- Bois : poussière mate + traces, lisible par signes et contraste de valeur.
- Métal : rouille (canal indépendant localisé aux joints et bords ; voir la section « Métal : test rouille » du 2026-11-12).

## 2026-11-12 — Métal : test rouille (principe validé)

Décision (validée développeur, 2026-11-12) : sur le métal, « sale » = rouille, gérée comme un canal indépendant de la base propre, localisé par un masque UV2 (joints entre panneaux, bords) et piloté par un paramètre d'instance `rouille` (0 = propre, 1 = rouillé). Rugosité de la base propre relevée par un plancher (0,42) : la rugosité d'origine de Metal055B (médiane 0,28) brûle sous une lumière en incidence miroir (mesuré en rendu approché : 85 % du plan à l'état propre, 35 % à 0,5).

- Base propre : Metal055B (CC0, ambientCG), rouille retirée (10 % de la surface), peinture niveau 2. Rugosité propre 0,45–0,60.
- Canal rouille : Metal056C (CC0, ambientCG), peinture niveau 2, rugosité mate (0,62–0,98), normale propre à 056C.
- Croissance : carte de seuil alignée sur l'albédo ; `rouille` = part de surface rouillée (0,5 = moitié). Le masque UV2 (canal V) décale l'avancée : joints et bords d'abord.
- Rendu vérifié dans Godot (PC du développeur, test_metal.tscn) : pas de reflet brûlé en rasante (lumière froide et chaude), rouille lisible à l'ensemble par contraste de valeur. Masque de test : bande de ~4 cm autour des joints (une bande de 12 cm se lisait comme une tache en croix). 🟡 valeur de départ.
- Fichiers : `game/tests/test_metal/` (metal.gdshader, test_metal.tscn, tex/). Scripts : build_metal_propre.py, rendu_metal.py.
- Réserves : (1) sous lumière chaude, la plaque propre rend beige (peinture claire sans reflet franc) et se lit moins comme du métal ; sous lumière froide, elle se lit comme du métal peint. (2) Le masque du test est fabriqué à la main pour un plan de 2 m ; la localisation des vrais modules viendra de leur UV2, à définir. (3) Normale de la base propre quasi plate. (4) Rouille à 100 % : garde les zones grises de 056C. (5) Gros plan et très gros plan réalistes, et lisibilité par signes, non jugés.

## 2026-11-12 — Pierre : mousse contre traces (coulures d'eau), principe validé

Décision (validée développeur, 2026-11-12) : sur la pierre, « trace » = coulures d'eau sombres (filets verticaux qui naissent des joints et sous les plaques de mousse). Canal indépendant `coulures` (paramètre d'instance 1 -> 0), masque en UV comme la mousse ; la coulure part avec la pierre sale (`proprete`) et ne dépend pas de la mousse. Suie réservée à la salle de la lanterne (test à part) ; extérieur : autre matériau, autre test.

- Valeurs retenues pour le masque v1 (point de départ, ajustables) : facteur d'albédo ×0,16 (« sombres fort »), contraste 0,45 ; pour la v2, voir la compensation ci-dessous. Rugosité et normale inchangées dans une coulure (la pierre sale a déjà une rugosité médiane de 0,37 : pas de reflet en plus).
- Superposition : la mousse épaisse recouvre la coulure ; la mousse fine la laisse transparaître (35 %). La mousse se distingue de la coulure par la teinte (olive) et la forme (plaque contre trait), pas par la valeur.
- Écartés : coulures à ×0,28 (trop faibles à l'ensemble) ; calcaire / salpêtre ×1,25 et ×1,5 (invisibles) et ×2,4 (se lit comme des bandes claires ou de la peinture, contredit « sale = plus sombre »).
- Vérifié dans Godot (PC du développeur, test_mousse_coulures.tscn, style « peint » niveau 2) : lisible à l'ensemble en lumière froide et chaude, lisible à 1 m, aucun reflet brûlé en rasante, états 0,5 (mousse et coulures) lisibles.
- Nettoyage progressif des coulures : défaut constaté puis corrigé le 2026-11-12. Avec un fondu étroit, une coulure à 0,5 se réduisait à un trait noir net (encre ou fissure). Réglage retenu : `douceur_coulures` 0,4 et `coulures_estompe` 0,6 (opacité plancher qui baisse avec le curseur). Vérifié dans Godot à 0,5, en lumière froide et chaude : visible, plus légère qu'à 1, sans trait noir. 🟡 valeurs de départ.
- Masque v2 « doux » retenu (validé développeur, 2026-11-12) : filets plus larges (65 au lieu de 80), cœur plafonné à 0,85, halo humide, bord moins franc, fondu d'entrée de quelques centimètres. Raison : la v1 se lisait comme de l'encre en gros plan (vérifié dans Godot, vue centre, proprete 0,45). Compromis assumé : à l'ensemble la v2 est un cran moins lisible que la v1 (vérifié, proprete 0, lumière chaude). Compensation : `coulures_contraste` 0,35 (au lieu de 0,45) et facteur d'albédo ×0,13 (au lieu de ×0,16). Vérifiée dans Godot (vue ensemble, proprete 0, mousse 1, lumière froide et chaude) : les traînées se lisent sans zoomer, presque aussi bien que la v1, sans contour dur. 🟡 valeurs de départ.
- Fichiers : `game/tests/test_mousse/` (mousse_coulures.gdshader, test_mousse_coulures.tscn et .gd, tex/masque_coulures_v2.png ; la v1 masque_coulures.png est gardée pour comparaison). Script : build_coulures.py (projet Claude, version 2).
- Réserves : (1) lecture à l'ensemble : seuls 80 filets, nombre non jugé (certains se lisent comme des fissures). (2) Masque fabriqué à la main pour un plan de 4 x 2 m ; la localisation sur les vrais modules viendra de leur UV2. (3) Netteté des filets : traitée par la v2 (voir ci-dessus) ; gros plan à 0,3 m vérifié dans Godot (vue gauche, proprete 0, mousse 1, lumière chaude) : plus d'aspect encre, les filets se lisent comme des taches d'eau, la mousse reste distincte par la teinte, rien ne brûle. Défaut restant : des filets parallèles et régulièrement espacés (départs trop alignés le long d'un joint) se lisent comme un peigne ou des griffes ; corrigé dans le masque v3 (2026-11-12) : espacement minimal de 22 cm entre filets voisins, 38 filets au lieu de 65, largeurs plus variées, dérive plus marquée. Vérifié dans Godot (vue ensemble, proprete 0, mousse 1, lumière chaude) : plus d'effet de peigne, filets espacés et irréguliers ; contrepartie : couverture divisée par deux (23 % à 12 %), lisibilité à l'ensemble juste suffisante. Réglage si trop discret : monter N dans build_coulures.py (55 par défaut ; l'espacement mini de 22 cm limite le nombre réel, 38 filets). Fichier : tex/masque_coulures_v3.png (bouton « Masque coulures » : v3 / v2). SUJET CLOS côté Art (2026-11-12) ; la v1 et la v2 sont gardées pour comparaison. (4) Nettoyage par `proprete` vérifié dans Godot à 0,3 / 0,6 / 1 (lumière froide et chaude, ensemble) : les coulures partent avec la pierre sale, la mousse reste (curseur indépendant, cohérent avec « mousse tenace »). Mi-nettoyage vérifié à 0,45 (vue centre, mousse 0, lumière froide et chaude) : la pierre sale part par plaques aux bords irréguliers et les coulures partent avec la plaque qui les porte, comme la poussière du bois ; la bascule entre 0,3 et 0,6 reste rapide (fondu étroit du masque de saleté, préexistant). Défaut en gros plan : les coulures restantes ont un bord noir net, plus proche de l'encre que de l'eau (réserve 3 confirmée). Non jugé : le gros plan à 0,3 m.

## 2026-11-12 — Seuil du fût : entrée et sortie (principe validé)

Décision (validée développeur, 2026-11-12) : l'entrée se fait par une ouverture percée dans le mur du fût, au niveau 0, au pied de la première marche. Module « mur avec ouverture » de 30° (ou 2 × 15°). Escalier inchangé. La sortie se fait par le haut. Ce sont deux points de passage.

- Largeur de passage : à confirmer (corde réelle d'un tronçon de 30° à R = 2,0 m ≈ 1,035 m, jambages compris). 🟡
- Sortie par le haut : module et sol vers la sortie à définir. 🟡
- Même règle d'export que les autres modules du fût (section « Modules du fût »).

## Points ouverts
- Valeurs de palette, résolution des textures, représentation sale / propre (TECHNICAL, phase 2), atmosphère globale ou par pièce (GDD).
- Hauteur d'étage (décide la hauteur de marche).
- Entrée (ouverture dans le mur, niveau 0) validée le 2026-11-12 : largeur de passage et module de sortie par le haut à définir. Gros bloc à l'entrée qui empiète sur les marches (non localisé).
- Noyau en coque témoin (0,25 m) ; version finale pleine à décider.
- Contact marche/mur : bord de marche à 4 segments d'arc, identique au mur.
- Import Godot non testé (échelle, normales, UV).
- Pierre : relief et reflets photographiques sur la pierre sale ; bords de mousse trop nets (version fût : bords adoucis, à vérifier en jeu).
- Mousse tenace (outil et déblocage non définis, hors périmètre Art : GDD / Engineering). Mousse contre traces : testée avec les coulures (voir section du 2026-11-12) ; reste la correction du nettoyage à 0,5.
- Métal : réserves du test rouille (beige sous lumière chaude, masque UV2 des vrais modules à définir, gros plans non jugés).
- Valeurs de palette par pièce ; détails fins effacés par la simplification.
- Rendu vérifié sur le PC du développeur pour le bois ; pas encore pour les modules du fût (import Godot).
- Comparaison Meshy vs Tripo (outil, lampe, caisse) et scène atelier : non faites. Licences gratuites à re-vérifier.
