class_name CleaningParams
extends Resource
## Constantes uniques du nettoyage localisé (TECHNICAL.md « Nettoyage localisé »).
## TOUTES PROVISOIRES, à régler en playtest.

## Une couche est invisible (et ne compte plus) quand épaisseur − propreté <= epsilon.
@export var epsilon: float = 0.05
## Fin de geste : quand le reste d'une face <= tau, ses résidus se fondent vers propre.
@export var tau: float = 0.02
## Durée du fondu de fin de geste (s).
@export var duree_fondu: float = 0.5
## Densité du masque d'état (grille fine, créée au premier contact du pinceau).
@export var texels_par_m: float = 64.0
## Densité de l'échantillonnage grossier de l'aire sale initiale (au chargement).
@export var texels_par_m_grossier: float = 16.0
