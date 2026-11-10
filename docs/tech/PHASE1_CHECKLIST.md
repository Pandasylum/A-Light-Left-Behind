# PHASE 1 — liste de vérification manuelle

Livrable : le joueur se déplace, prend, transporte, oriente et place des objets sans blocage.
Scène : `res://rooms/test/greybox.tscn` (lancer la scène depuis l'éditeur). Touches provisoires : ZQSD/WASD, Maj (marche lente), E (interagir), G (poser), Q (changer d'objet), molette (tourner), I (inventaire), Échap (libérer la souris).
Interface provisoire : les messages s'affichent sous forme de clés brutes (aucune traduction).

## Vérifications
| # | Étapes | Résultat attendu |
|---|--------|------------------|
| 1 | Lancer la scène. Se déplacer, tourner la vue, marcher avec Maj. | Mouvement fluide, regard à la souris, marche plus lente avec Maj, bordures infranchissables. |
| 2 | Viser un petit objet à moins de 2 m. | Un indice d'interaction apparaît ; il disparaît quand on regarde ailleurs. |
| 3 | E sur un SMALL. | L'objet est en main ; le label en bas à gauche affiche son nom. |
| 4 | E sur un second SMALL. | Rangé à la ceinture (capacité 1) ; le label ne change pas. E sur un troisième : message `carry.belt_full`. |
| 5 | Main : SMALL, ceinture avec un emplacement libre. E sur le MEDIUM. | Le SMALL est rangé automatiquement ; le MEDIUM est en main. |
| 6 | Avec le MEDIUM en main : E sur un SMALL. | Refus `carry.hands_full`. Q ne fait rien d'utile (`carry.cycle_blocked`). |
| 7 | I. | Le panneau liste Main et la ceinture (nom et catégorie, ou « vide »). Le joueur peut bouger, la souris reste capturée. I de nouveau le masque. |
| 8 | Viser le dessus de la table avec le MEDIUM, tourner à la molette. | Aperçu vert, tourne par paliers. |
| 9 | G sur la table. | Le MEDIUM est posé, orienté comme l'aperçu. |
| 10 | E sur le MEDIUM posé. | Repris en main. |
| 11 | Reposer le MEDIUM sur la table, puis Q (SMALL en main) et G sur le dessus du MEDIUM. | Le SMALL est posé sur le MEDIUM. |
| 12 | E sur le MEDIUM chargé. | Refus `carry.supports_object` ; le SMALL doit d'abord être repris. |
| 13 | Viser le bord de la table avec un SMALL ; aperçu orange ; G. | L'objet tombe verticalement, message `place.fell`, jamais coincé dans un support. |
| 14 | E sur l'objet tombé. | Il est repris. |
| 15 | Viser le plot (0,3 m) avec un LARGE ; G. | Aperçu orange, l'objet tombe puis est dégagé du plot (ou `place.blocked`, rien ne change). |
| 16 | Mains libres, E sur un meuble libre (au sol, z = 3,4), le déplacer, G. | Le meuble est posé ailleurs ; il porte un SMALL posé dessus ; le reprendre est refusé tant qu'il porte une charge. |
| 17 | Viser un flanc ou le ciel avec un objet en main ; G. | Aperçu masqué, message `place.no_surface`, rien ne change. |
| 18 | Échap, puis I et E. | Souris libérée : ni inventaire, ni prise, ni pose. Clic gauche recapture la souris. |
| 19 | Marcher hors de la salle (ou tomber sous la limite). | Retour au point de départ. |
| 20 | Parcourir tout ce qui précède. | Aucun blocage, aucune erreur dans la console. |

## Valeurs à régler (provisoires, aucune nouvelle valeur proposée)
| Valeur | Fichier / constante | Valeur actuelle |
|--------|---------------------|-----------------|
| Marge au bord | `game/data/placement_rules.gd` — `edge_margin` | 0,02 m |
| Couverture minimale | `game/data/placement_rules.gd` — `min_support_coverage` | 0,6 |
| Pas de rotation | `game/data/placement_rules.gd` — `rotation_step_degrees` | 15° |
| Vitesse de marche | `game/systems/player/player.gd` — `walk_speed` | 2,5 m/s |
| Vitesse de marche lente | `game/systems/player/player.gd` — `slow_walk_speed` | 1,2 m/s |
| Sensibilité souris | `game/systems/player/player.gd` — `mouse_sensitivity` | 0,002 rad/pixel |
| Portée d'interaction | `game/systems/interaction/interaction_sensor.gd` — `reach` | 2,0 m |
| Capacité de ceinture | `game/systems/player/player.gd` — `belt_capacity` (1 à 5) | 1 |
| Itérations de chute | `game/systems/placement/placement_landing.gd` — `MAX_ITERATIONS` | 8 |
| Table d'empilement | `game/systems/placement/placement_check.gd` — `STACK_TABLE` | SMALL sur SMALL/MEDIUM/LARGE ; MEDIUM sur LARGE ; LARGE et FIXED sur rien |
| Seuil de chute du joueur | `game/systems/player/player.gd` — `fall_limit_y` | −10 m |
