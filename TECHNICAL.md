# TECHNICAL — A Light Left Behind

Propriétaire : projet Godot Engineering. Dernière mise à jour : 2026-11-10.
Légende : ✅ décision validée · 🟡 à décider en Phase 0

## Contraintes validées ✅
- Moteur : Godot 4.6. Plateforme : PC uniquement (mobile abandonné le 2026-11-09).
- Un seul dépôt Git. Une PR par sujet.
- Entrées : clavier/souris de référence, manette en bonus non engagé. Toutes les entrées passent par des actions de l'Input Map, jamais par des touches en dur.
- Systèmes modulaires et réutilisables. Contenu séparé du code par des ressources et des données. Pas de script propre à une pièce quand une donnée suffit.
- Pas de sur-ingénierie.
- Le 100 % d'une pièce repose sur des unités explicites (surfaces, objets). Les découvertes facultatives sont comptées à part.
- Sauvegarde locale. Intégrité validée avant toute écriture.

## À décider en Phase 0 🟡
1. Moteur de rendu (Forward+ ou Compatibility).
2. Langage : GDScript seul ou non.
3. Structure de dossiers et conventions de nommage.
4. Représentation de la saleté (masque ou zones), à tester en Phase 2.
5. Architecture et format de sauvegarde.
6. Représentation des objets et de leurs emplacements de rangement.
