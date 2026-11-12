# ART BIBLE — A Light Left Behind

Propriétaire : projet Art Direction & Assets. Dernière mise à jour : 2026-11-12.
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
- Salle de vie : bois, textiles, mobilier ancien.
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
- Format : 2 400 × 1 650 px par anneau (≈ 764 px/m), tuile d’un tour × 1 anneau (3,1416 × 2,16 m), UV1 en mètres selon la Règle d’export §5 (échelle de matériau 1/3,1416 ; 1/2,16), origine sur une limite de panneau. Normal map OpenGL Y+ en linéaire, albédo en sRGB. Import en VRAM standard, sans HQ. Lecture en production par projection cylindrique monde : non testée, à vérifier à la première intégration du noyau. 🟡
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
- Métal : rouille (non testé en détail).

## Points ouverts
- Valeurs de palette, résolution des textures, représentation sale / propre (TECHNICAL, phase 2), atmosphère globale ou par pièce (GDD).
- Hauteur d'étage (décide la hauteur de marche).
- Entrée et sortie du fût : modules « seuil » et sol vers la sortie à définir. Gros bloc à l'entrée qui empiète sur les marches (non localisé).
- Noyau en coque témoin (0,25 m) ; version finale pleine à décider.
- Contact marche/mur : bord de marche à 4 segments d'arc, identique au mur.
- Import Godot non testé (échelle, normales, UV).
- Pierre : relief et reflets photographiques sur la pierre sale ; bords de mousse trop nets (version fût : bords adoucis, à vérifier en jeu).
- Mousse contre traces non testée ; mousse tenace (outil et déblocage non définis).
- Métal : test sale/propre à faire.
- Valeurs de palette par pièce ; détails fins effacés par la simplification.
- Rendu vérifié sur le PC du développeur pour le bois ; pas encore pour les modules du fût (import Godot).
- Comparaison Meshy vs Tripo (outil, lampe, caisse) et scène atelier : non faites. Licences gratuites à re-vérifier.
