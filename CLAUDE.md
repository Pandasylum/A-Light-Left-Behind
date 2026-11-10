# CLAUDE.md — règles permanentes pour Claude Code

Jeu : A Light Left Behind (Godot 4.6, PC uniquement, développeur solo). Règles fondamentales : `PROJECT_RULES.md`. Décisions de conception : `GDD.md` (fait foi). Avancement : `ROADMAP.md`. Carte du code : `SYSTEMS.md`.

## Cadre de travail
- Une session = un sujet = une branche = une PR. Tu ne fusionnes jamais.
- Tu exécutes le prompt reçu. Aucune décision de conception ou d'architecture non validée. Si une ambiguïté importante bloque : arrête-toi et demande.
- Reste dans le périmètre du prompt. Ne modifie rien d'autre, sauf SYSTEMS.md (voir Documents).

## Lectures
- Commence par `SYSTEMS.md` plutôt que d'explorer le dépôt.
- Maximum 2 fichiers lus en entier par tâche, sauf autorisation. Préfère grep ou sed ciblés. Aucune lecture générale du projet.
- Jamais de réécriture complète d'un fichier pour une modification limitée.

## Tests et builds
- Documentation seule : aucun test. Visuel : vérification visuelle suffisante. Logique : tests ciblés. Jamais de suite complète par réflexe.
- Si un test échoue, analyse la sortie avant toute relance.
- Si tu dépasses un build ou un test par résultat, arrête-toi et demande.
- Aucun polling, aucune vérification répétée pour confirmer un résultat établi.

## Documents
- Mets à jour `SYSTEMS.md` à chaque PR qui ajoute ou déplace un système, une scène ou un script important (une ligne par entrée).
- Ne crée aucun nouveau document sans demande explicite du prompt.
- Modifications ciblées, jamais de réécriture complète.

## Git
- Branche indiquée par le prompt. Un commit clair, une PR avec description courte.
- Si un push échoue (403 ou autre) : une seule tentative, puis arrête-toi et signale.

## Rapport final (toujours)
15 lignes maximum : fait / pas fait / décisions à valider. Pas de recopie de code ni de diff. Signale les problèmes et les tests réellement exécutés.
