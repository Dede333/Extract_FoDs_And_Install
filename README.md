Bonjour,

Signification des paramètres en début de script (powershell):
- `$FodIsoPath` Chemin vers votre ISO FoD de Windows 11 24H2
- `$Locale`     Langue des FoD à utiliser (`fr-FR`, `en-US`, etc.)
- `$RepoPath`   Dossier où sera généré le dépôt offline
- `$WimPaths`   Liste des images WIM à traiter
- `$MountBase`  Dossier temporaire de montage WIM
- '$IdxWim'     Index of WIM (une version Windows PRO est requise pour l'utilisation des outils RSAT)
- '$SourceCabFolder' lieu où se trouve les FoDs de l'ISO FoDs de Microsoft (fichier .cab)

Une fois les FoDs extrait dans un nouveau dépôt, on cible les FoDs concernant les outils RSAT et enfin, on les installes dans l'image WIM.

Vous pouvez télécharger l'ISO Microsoft FoDs à l'adresse suivante:

https://learn.microsoft.com/en-us/azure/virtual-desktop/windows-11-language-packs?WT.mc_id=AZ-MVP-5004580 (Prerequis)
https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66749/22621.1.220506-1250.ni_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso

Cordialement
