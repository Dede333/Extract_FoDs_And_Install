Bonjour,

`$FodIsoPath` Chemin vers votre ISO FoD de Windows 11 24H2
`$Locale`     Langue des FoD à utiliser (`fr-FR`, `en-US`, etc.)
`$RepoPath`   Dossier où sera généré le dépôt offline
`$WimPaths`   Liste des images WIM à traiter
`$MountBase`  Dossier temporaire de montage WIM
'$IdxWim'     Index of WIM (Windows PRO is require for use RSAT)
'$SourceCabFolder' lieu où se trouve les FoDs de l'ISO FoDs de Microsoft (fichier .cab)

Une fois les FoDs extrait dans un nouveau dépôt, on cible les FoDs concernant les outils RSAT et enfin, on les installes dans l'image WIM.

Cordialement
