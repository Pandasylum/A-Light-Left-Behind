# ART BIBLE — A Light Left Behind

Propriétaire : projet Art Direction & Assets. Dernière mise à jour : 2026-11-10.
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

### Points ouverts
Valeurs de palette, résolution des textures, représentation sale / propre (TECHNICAL, phase 2), atmosphère globale ou par pièce (GDD).

2026-11-10 : Protocole de test de style validé. Scène : coin d’atelier, une caméra, 3 matériaux (bois, pierre, métal rouillé), 3 objets. 4 captures : froid/chaud × propre/sale. Le style « peint + éclairage réaliste » reste NON OFFICIEL jusqu’au verdict.

2026-11-11 : Style (validé par le développeur). « Stylisé réaliste » = textures photo simplifiées (niveau 2) + éclairage réaliste. « Peint à la main » est abandonné. Cohérent avec PROJECT_RULES §4.1. Condition : respecter l’ambiance des références (atelier en bois chaud, lanterne rouillée, escalier de bois dans une tour de pierre). Statut : NON OFFICIEL jusqu’au test bois (sale/propre, froid/chaud).

2026-11-11 : Sens de « sale » par matériau. Pierre : humidité et mousse ; restaurée, elle devient plus sèche et plus claire. Bois : voile de poussière mate et traces. Métal : rouille. Le contraste de valeur reste suffisant pour lire la saleté. Pour le bois, la lisibilité passe par les signes (poussière, traces) en plus de la valeur.

2026-11-11 : Palette, mises à jour. En lumière chaude, la pierre rend gris-brun. Nouvelle ligne « mousse » : vert olive sombre, valeur de départ ≈ 
#313B12 (moyenne mesurée sur la texture Moss002 étalonnée), à ajuster.

2026-11-11 : Mousse sur pierre, test technique concluant. Couche séparée (albédo, rugosité et normale CC0 Moss002, niveau 2) pilotée par un masque d’épaisseur ; seuil par instance, les zones fines partent en premier. La pierre de base doit être sans mousse. La mousse est mate, la pierre sale est brillante (humide). Points ouverts : bords trop nets (à corriger dans le masque), relief et reflets photographiques sur la pierre sale, mousse contre traces et crasse non testée, mousse tenace non testée.
