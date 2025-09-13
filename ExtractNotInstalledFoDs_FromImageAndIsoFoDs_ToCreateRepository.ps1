# === CONFIGURATION ===
$FodIsoPath    = "F:\ISOs FoDs Officiel Microsoft 31082025\Win11\26100.1.240331-1435.ge_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso" # Image officiel FoDs, Microsoft (cf doc azure)
$Locale        = "fr-FR"									 # langue utilisée pour les FoDs
$RepoPath      = "D:\FoDRepo"								 # dépôt pour la construction des FoDs qui ne sont pas encore installés dans l'image WIM (offline)
$WimPaths      = @(
    "D:\x64\Sources\install.wim"							 # Noms des images WIM (offline) Ã  modifier	
)
$IdxWim = 6													 # Windows Pro (par défaut)
$XmlCabRelPath = "LanguagesAndOptionalFeatures\metadata\DesktopTargetCompDBForISO_FOD_$Locale.xml.cab" # en fonction de la langue choisie
$MountBase     = "D:\Mounts"								 # pour le point de montage de l'ISO FoDs
$SourceCabFolder = "LanguagesAndOptionalFeatures\"			 # lieu où se trouve les FoDs de l'ISO FoDs de Microsoft

# === 1. Monter ISO FoD ===
$fodDrive = (Mount-DiskImage -ImagePath $FodIsoPath -ErrorAction Stop | Get-Volume).DriveLetter
$fodBase  = "$fodDrive`:\$SourceCabFolder"

# === 2. Extraire le fichier XML des Features FoD ===
$tempXml = Join-Path $Env:TEMP "FoD_$Locale.xml"			# C:\Users\xxxxxxx\AppData\Local\Temp\FoD_fr-FR.xml
#write-host 'Valeur de $tempXml: '$tempXml
$xmlCabPath = "$fodDrive`:\$XmlCabRelPath"					# E:\LanguagesAndOptionalFeatures\metadata\DesktopTargetCompDBForISO_FOD_fr-FR.xml.cab
#write-host 'Valeur de $xmlCabPath: '$xmlCabPath
expand.exe $xmlCabPath -F:* $tempXml

[xml]$compDb = Get-Content $tempXml

# === 3. Générer le mapping Feature / Packages
$mapping = @{}
foreach ($feature in $compDb.CompDB.Features.Feature) {
    $id = $feature.FeatureID								# FeatureID
	#write-host 'Valeur de $id:'$id
    $pkg = $feature.Packages.Package.ID						# Package.ID
	#write-host 'Valeur de $pkg:'$pkg
    if ($pkg) { $mapping[$id] = $pkg }						# si un ou plusieurs packages sont présents, on fait une association (id,pkgs)
}

# === 4. Créer le dépôt offline FoD
Write-Host "`nCréation du dépôt offline : $RepoPath" -ForegroundColor Cyan
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Path $RepoPath'\'$SourceCabFolder # efface un éventuel ancien dossier (dépôt) présent sur disque
New-Item -ItemType Directory -Path $RepoPath'\'$SourceCabFolder | Out-Null	# création d'un nouveau dépôt

$allCabs = Get-ChildItem -Path $fodBase -Filter *.cab -Recurse						# filtre tous les fichiers .cab
$requiredCabs = $mapping.Values | Sort-Object -Unique								# croise les fichiers uniquement nécessaires
foreach ($cabName in $requiredCabs) {												# pour la comparaison de fichiers
    $cabNameBis = $cabName.split(' ')												# Traitement, si le nombre de paquage est > 1
	foreach ($str in $cabNameBis) {													# pour chaque paquage
	    #write-host 'Valeur de $str'$str
        $src = $allCabs | Where-Object { $_.Name -eq "$str.cab" }					# si correspondance
	    #write-host 'Valeur de $src:'$src
        if ($src) { 
		    Copy-Item -Path $src.FullName -Destination $RepoPath'\'$SourceCabFolder } # recopie le fichier correspondant à la langue dans le dépôt
			[String]$srcBase = $src													# isole le nom de fichier pour traitement
			$srcBase = $srcBase.replace("~fr-FR~","~~")								# traitement du nom pour avoir le FoDs de base (neutre) 
			#write-host 'Valeur de $srcBase:'$srcBase								# affiche le FoD de base (langue neutre)
			$TmpFile = "$fodBase$srcBase"
			#write-host 'Valeur de TmpFile:'$TmpFile
			if ($TmpFile -ne $fodBase){
			    Copy-Item -Path $TmpFile -Destination $RepoPath'\'$SourceCabFolder		# ajoute le FoDs de base au dépôt
			}
	}
}

# Ajouter metadata nécessaires
$metaCabs = $allCabs | Where-Object { $_.Name -match "FoDMetadata|Downlevel" }		# fichiers metadata et downlevel
$metaCabs | ForEach-Object { Copy-Item $_.FullName -Destination $RepoPath'\'$SourceCabFolder } # que l'on recopie dans dépôt

Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Path $RepoPath'\'$SourceCabFolder'metadata' # efface un éventuel ancien dossier (dépôt) présent sur disque
New-Item -Path $RepoPath'\'$SourceCabFolder -Name 'metadata' -ItemType Directory | Out-Null # création du dossier metadata dans le dépôt
$allCabs = Get-ChildItem -Path "$fodBase\metadata" -Filter *.cab -Recurse			# répertoire metadata (obligatoire)
$metaCabs = $allCabs | Where-Object { $_.Name -match "Conditions|Neutral|$Locale" }	# fichiers metadata et downlevel
$metaCabs | ForEach-Object { Copy-Item $_.FullName -Destination $RepoPath'\'$SourceCabFolder'metadata' } # que l'on recopie dans dépôt

# === 5. Boucle sur toutes les images WIM ===
foreach ($wim in $WimPaths) {														# traitement sur tous les fichiers WIM
    $imageName = Split-Path $wim -Leaf												# filename.wim
    $mountDir = Join-Path $MountBase ([System.IO.Path]::GetFileNameWithoutExtension($imageName))
    New-Item -ItemType Directory -Path $mountDir -Force | Out-Null					# creation d'un répertoire portant le nom de l'image (WIM) dans $MountBase

    Write-Host "`nMontage de l'image : $imageName, index wim: $IdxWim" -ForegroundColor Yellow
    #Dism /Mount-Wim /WimFile:$wim /Index:1 /MountDir:$mountDir | Out-Null
    Dism /Mount-Wim /WimFile:$wim /Index:$IdxWim /MountDir:$mountDir				# Monte l'image WIM pour un index spécifique
	
    # Rechercher les capabilities RSAT manquantes
    #$caps = Get-WindowsCapability -Path $mountDir -Online:$false | Where-Object { $_.Name -like "Rsat.*~~~~0.0.1.0" -and $_.State -ne "Installed" }
	$caps = Get-WindowsCapability -Path $mountDir -Name "Rsat.*~~~~0.0.1.0" | Where-Object {$_.State -ne "Installed" }
	
    foreach ($cap in $caps) {
        Write-Host "Installation : $($cap.Name)" -ForegroundColor Green
        try {
            Add-WindowsCapability -Path $mountDir -Name $cap.Name -Source $RepoPath'\'$SourceCabFolder -LimitAccess -ErrorAction Stop
        } catch {
            Write-Warning "Erreur d'installation pour $($cap.Name) : $_"
        }
    }

    # Valider et démonter
    #Dism /Unmount-Wim /MountDir:$mountDir /Commit | Out-Null
	Dism /Unmount-Wim /MountDir:$mountDir /Commit									# applique les modifications dans l'image WIM
    Write-Host "Image $imageName traitée." -ForegroundColor Cyan
}

# Nettoyer le montage ISO
#Dismount-DiskImage -ImagePath $FodIsoPath | Out-Null
Dismount-DiskImage -ImagePath $FodIsoPath											# Démonte ISO FoDs

Write-Host "`Traitement terminé pour toutes les images WIM."