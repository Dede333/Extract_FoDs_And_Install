# === CONFIGURATION ===
$FodIsoPath    = "F:\ISOs FoDs Officiel Microsoft 31082025\Win11\26100.1.240331-1435.ge_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso" # Image officiel FoDs, Microsoft (cf doc azure)
$Locale        = "fr-FR"									 # langue utilis�e pour les FoDs
$RepoPath      = "D:\FoDRepo"								 # d�p�t pour la construction des FoDs qui ne sont pas encore install�s dans l'image WIM (offline)
$WimPaths      = @(
    "D:\x64\Sources\install.wim"							 # Noms des images WIM (offline) à modifier	
)
$IdxWim = 6													 # Windows Pro (par d�faut)
$XmlCabRelPath = "LanguagesAndOptionalFeatures\metadata\DesktopTargetCompDBForISO_FOD_$Locale.xml.cab" # en fonction de la langue choisie
$MountBase     = "D:\Mounts"								 # pour le point de montage de l'ISO FoDs
$SourceCabFolder = "LanguagesAndOptionalFeatures\"			 # lieu o� se trouve les FoDs de l'ISO FoDs de Microsoft

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

# === 3. G�n�rer le mapping Feature / Packages
$mapping = @{}
foreach ($feature in $compDb.CompDB.Features.Feature) {
    $id = $feature.FeatureID								# FeatureID
	#write-host 'Valeur de $id:'$id
    $pkg = $feature.Packages.Package.ID						# Package.ID
	#write-host 'Valeur de $pkg:'$pkg
    if ($pkg) { $mapping[$id] = $pkg }						# si un ou plusieurs packages sont pr�sents, on fait une association (id,pkgs)
}

# === 4. Cr�er le d�p�t offline FoD
Write-Host "`nCr�ation du d�p�t offline : $RepoPath" -ForegroundColor Cyan
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Path $RepoPath'\'$SourceCabFolder # efface un �ventuel ancien dossier (d�p�t) pr�sent sur disque
New-Item -ItemType Directory -Path $RepoPath'\'$SourceCabFolder | Out-Null	# cr�ation d'un nouveau d�p�t

$allCabs = Get-ChildItem -Path $fodBase -Filter *.cab -Recurse						# filtre tous les fichiers .cab
$requiredCabs = $mapping.Values | Sort-Object -Unique								# croise les fichiers uniquement n�cessaires
foreach ($cabName in $requiredCabs) {												# pour la comparaison de fichiers
    $cabNameBis = $cabName.split(' ')												# Traitement, si le nombre de paquage est > 1
	foreach ($str in $cabNameBis) {													# pour chaque paquage
	    #write-host 'Valeur de $str'$str
        $src = $allCabs | Where-Object { $_.Name -eq "$str.cab" }					# si correspondance
	    #write-host 'Valeur de $src:'$src
        if ($src) { 
		    Copy-Item -Path $src.FullName -Destination $RepoPath'\'$SourceCabFolder } # recopie le fichier correspondant � la langue dans le d�p�t
			[String]$srcBase = $src													# isole le nom de fichier pour traitement
			$srcBase = $srcBase.replace("~fr-FR~","~~")								# traitement du nom pour avoir le FoDs de base (neutre) 
			#write-host 'Valeur de $srcBase:'$srcBase								# affiche le FoD de base (langue neutre)
			$TmpFile = "$fodBase$srcBase"
			#write-host 'Valeur de TmpFile:'$TmpFile
			if ($TmpFile -ne $fodBase){
			    Copy-Item -Path $TmpFile -Destination $RepoPath'\'$SourceCabFolder		# ajoute le FoDs de base au d�p�t
			}
	}
}

# Ajouter metadata n�cessaires
$metaCabs = $allCabs | Where-Object { $_.Name -match "FoDMetadata|Downlevel" }		# fichiers metadata et downlevel
$metaCabs | ForEach-Object { Copy-Item $_.FullName -Destination $RepoPath'\'$SourceCabFolder } # que l'on recopie dans d�p�t

Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Path $RepoPath'\'$SourceCabFolder'metadata' # efface un �ventuel ancien dossier (d�p�t) pr�sent sur disque
New-Item -Path $RepoPath'\'$SourceCabFolder -Name 'metadata' -ItemType Directory | Out-Null # cr�ation du dossier metadata dans le d�p�t
$allCabs = Get-ChildItem -Path "$fodBase\metadata" -Filter *.cab -Recurse			# r�pertoire metadata (obligatoire)
$metaCabs = $allCabs | Where-Object { $_.Name -match "Conditions|Neutral|$Locale" }	# fichiers metadata et downlevel
$metaCabs | ForEach-Object { Copy-Item $_.FullName -Destination $RepoPath'\'$SourceCabFolder'metadata' } # que l'on recopie dans d�p�t

# === 5. Boucle sur toutes les images WIM ===
foreach ($wim in $WimPaths) {														# traitement sur tous les fichiers WIM
    $imageName = Split-Path $wim -Leaf												# filename.wim
    $mountDir = Join-Path $MountBase ([System.IO.Path]::GetFileNameWithoutExtension($imageName))
    New-Item -ItemType Directory -Path $mountDir -Force | Out-Null					# creation d'un r�pertoire portant le nom de l'image (WIM) dans $MountBase

    Write-Host "`nMontage de l'image : $imageName, index wim: $IdxWim" -ForegroundColor Yellow
    #Dism /Mount-Wim /WimFile:$wim /Index:1 /MountDir:$mountDir | Out-Null
    Dism /Mount-Wim /WimFile:$wim /Index:$IdxWim /MountDir:$mountDir				# Monte l'image WIM pour un index sp�cifique
	
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

    # Valider et d�monter
    #Dism /Unmount-Wim /MountDir:$mountDir /Commit | Out-Null
	Dism /Unmount-Wim /MountDir:$mountDir /Commit									# applique les modifications dans l'image WIM
    Write-Host "Image $imageName trait�e." -ForegroundColor Cyan
}

# Nettoyer le montage ISO
#Dismount-DiskImage -ImagePath $FodIsoPath | Out-Null
Dismount-DiskImage -ImagePath $FodIsoPath											# D�monte ISO FoDs

Write-Host "`Traitement termin� pour toutes les images WIM."