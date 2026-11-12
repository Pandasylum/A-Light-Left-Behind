# A LIGHT LEFT BEHIND — AUDIO BIBLE

Dernière mise à jour : 2026-11-13
Statut : décisions sonores validées uniquement. Les propositions et idées n'entrent pas ici tant qu'elles ne sont pas validées.

**Légende** : ✅ décision validée · 💡 piste non engagée · 🟡 à préciser (valeur non décidée)

Références : `PROJECT_RULES.md` (fondamental, §6), `GDD.md` (gameplay), `SOUND_LIST.md` (liste et suivi des sons).

---

## 1. Direction sonore ✅

- Ambiance initiale froide et mélancolique : vent, pluie, craquements, bâtiment abandonné.
- À mesure que le phare est restauré, l'intérieur devient plus doux et chaleureux. L'extérieur reste froid et exposé.
- Musique discrète.
- Sons d'interaction satisfaisants.
- Éviter les sons forts ou répétitifs.
- Aucun chronomètre, score ni récompense artificielle : pas de jingle de victoire.
- Cinématiques (phase tardive) : voix françaises et sous-titres.

## 2. Catégories de sons ✅

Source : `PROJECT_RULES.md` §6.

1. Ambiances : vent, pluie, mer, vagues lointaines, craquements du bâtiment, bruits extérieurs étouffés.
2. Déplacements : pas sur bois, pierre, métal ; escaliers.
3. Manipulation des objets : pose (bois, métal, verre), déplacement d'un objet sur une surface.
4. Rangement : tiroirs, portes, coffre, boîte, armoire.
5. Nettoyage : sons des outils de nettoyage (voir §6).
6. Restauration : outils de réparation, mécanismes réparés.
7. Mécanismes : engrenages, leviers, moteur, machines, mécanismes du phare.

Retours d'interface et d'événements : discrets (fin de surface, notifications).

## 3. Hiérarchie des niveaux ✅

- Les sons d'interaction sont légèrement plus présents que les ambiances.
- Les ambiances restent discrètes et immersives.
- La musique reste discrète.
- 🟡 Niveaux chiffrés (dB par bus), ducking, bus Godot : non décidés. Spécification à transmettre à Godot Engineering une fois les premiers sons écoutés en contexte.

## 4. Évolution de l'ambiance avec la restauration ✅ (principe) / 🟡 (réalisation)

- Principe : intérieur froid et abandonné au début, plus doux et chaleureux avec la restauration. Extérieur toujours froid et exposé.
- Cohérent avec la lumière du GDD (froide au début, plus chaude avec la restauration).
- 🟡 Mécanisme (couches d'ambiance, paliers, fondus) : non décidé.

## 5. Règles de variation ✅

- Sons fréquents : plusieurs variantes, avec hauteur légèrement différente.
- Retour de fin de surface : plusieurs variantes de hauteur légèrement différente, pour éviter la saturation (GDD §4).
- 🟡 Nombre de variantes par famille et amplitude de variation de hauteur : non décidés (voir `SOUND_LIST.md`).

## 6. Sons liés au gameplay (GDD) ✅

Outils (GDD §7) : éponge, raclette, serpillière, seau (rinçage) ; marteau, outil multifonction (réparation).

- Le nettoyage et la réparation produisent un retour visuel et sonore satisfaisant.
- La saleté disparaît sous l'outil (nettoyage local) : le son suit le geste, pas une surface entière.
- Fin de surface : petit retour visuel et sonore discret.
- Rinçage : geste court, l'outil sale en main, interaction avec le seau qui reste au sol.
- Aucun son de récompense artificielle (voir §1).

## 7. Chaîne de production ✅

- Développeur solo avec peu de compétences en conception sonore : privilégier les sons générés par IA, les bibliothèques existantes et les traitements simples.
- Outils à examiner : ElevenLabs Sound Effects, Adobe Firefly Sound Effects, bibliothèques libres ou sous licence compatible, Audacity (montage et traitement).
- Privilégier : cohérence d'ensemble, sons réutilisables et variations d'une même source, couches simples superposées, ambiances en boucle sans coupure perceptible.
- Un son généré n'est jamais adopté sans vérification (artefacts, boucle, niveau, bruit parasite).
- Tester un son avant d'en produire une série. Faire valider le premier son d'une famille avant de la décliner.
- Un son n'est terminé qu'après écoute en contexte dans le jeu.
- Priorité aux sons fréquents (nettoyage, pose d'objets, pas) avant les sons rares.
- 🟡 Outil de génération retenu : non décidé.

## 8. Licences ✅

- Droits d'usage commercial vérifiés avant l'adoption de tout son.
- Source, outil, date et licence consignés dans `SOUND_LIST.md` pour chaque son.

## 9. Formats et intégration Godot 🟡

Non décidés : format des fichiers, fréquence d'échantillonnage, nommage, réglages d'import, boucles. À valider avant la première production, puis à inscrire ici.

---

## Points ouverts

1. Niveaux chiffrés et structure des bus (avec Godot Engineering).
2. Format, nommage et réglages d'import.
3. Outil de génération principal et abonnement éventuel (coûts, licence commerciale).
4. Mécanisme d'évolution de l'ambiance avec la restauration.
5. Musique : rôle, quand elle joue, quand elle se tait.

## Contradictions entre documents à traiter par Direction

- `PROJECT_RULES.md` §6.5 cite brosse, chiffon, pulvérisateur, aspiration. Le GDD §7 fixe éponge, raclette, serpillière, seau. Le GDD prime pour les sons de nettoyage ; à confirmer.
- `PROJECT_RULES.md` §6.6 cite ponçage et polissage. Le GDD ne prévoit que le marteau et l'outil multifonction. À confirmer.
- `PROJECT_RULES.md` §7 indique Godot 4.6 ; le brief Sound Design indique Godot 4.7.2.
