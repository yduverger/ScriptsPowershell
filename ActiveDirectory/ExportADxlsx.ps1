#Variable de recherche utilisateurs dans l'AD
$SearchOU = 
"OU=OU1,OU=Users,OU=MyBusiness,DC=DOMAIN,DC=LOCAL",
"OU=OU2,OU=Users,OU=MyBusiness,DC=DOMAIN,DC=LOCAL"

$SearchGRP = "_(R|RXW)$"

#Variables d'environment
$Date = Get-Date -Format "yyyyMMddHHmm"
$Folder = "C:\Users\%user%\Desktop\ExportAD\"
$FolderTmp = $Folder + "TMP\"
$File = $Date + "_PS1_ExportADTree.csv"
$PathFile = $Folder + $File

#Récupère les utilisateurs de l'AD
$Users = $SearchOU | ForEach { Get-ADUser -Filter * -Properties * -SearchBase $_ } | Select-Object SamAccountName, Name, LastLogonDate, Enabled | Sort Name
#Récupère la liste des groupes de sécurité (arborescence)
$GroupsList = Get-ADGroup -Filter * | Select-Object Name | Where-Object { $_.Name -Match $SearchGRP } | Sort Name

#Instancie un dossier vide temporaire
If (Test-Path $FolderTmp) {
    Get-ChildItem $FolderTmp -Recurse | Remove-Item
}
Else { 
    New-Item -Path $FolderTmp -ItemType "directory" 
}

#Supprime le fichier Export s'il existe déjà
If (Test-Path $PathFile) { 
    Remove-Item -Path $PathFile 
}

#Crée le fichier header
$HeaderFile = "header.tmp"
New-Item -Path $FolderTmp -Name $HeaderFile -ItemType "file"
$PathHeaderFile = $FolderTmp + $HeaderFile

#Crée le fichier enabled
$EnabledFile = "enabled.tmp"
New-Item -Path $FolderTmp -Name $EnabledFile -ItemType "file"
$PathEnabledFile = $FolderTmp + $EnabledFile

#Crée le fichier content
$ContentFile = "content.tmp"
New-Item -Path $FolderTmp -Name $ContentFile -ItemType "file"
$PathContentFile = $FolderTmp + $ContentFile

#Initie les données d'entête
$Line = New-Object -TypeName psobject
$Line | Add-Member -MemberType NoteProperty -Name GroupName -Value "GroupName"

ForEach ($User in $Users) {
    $Line | Add-Member -MemberType NoteProperty -Name $User.SamAccountName -Value $User.SamAccountName
}
$Line | Export-Csv -Path $PathHeaderFile -NoTypeInformation -Delimiter ';'

#Initie les données d'activité
$Line = New-Object -TypeName psobject
$Line | Add-Member -MemberType NoteProperty -Name Enabled -Value "Enabled"

ForEach ($User in $Users) {
    $Line | Add-Member -MemberType NoteProperty -Name $User.SamAccountName -Value $User.Enabled
}
$Line | Export-Csv -Path $PathEnabledFile -NoTypeInformation -Delimiter ';'

#Parcours tous les groupes
ForEach ($Group in $GroupsList) {
    $Line = New-Object -TypeName psobject
    $Line | Add-Member -MemberType NoteProperty -Name GroupName -Value $Group.Name

    ForEach ($User in $Users) {
        #Récupère les droits arbo de l'utilisateur
        $UserGroups = Get-ADPrincipalGroupMembership $($User.SamAccountName) | Select-Object Name | Sort Name | 
            Where-Object { $_.Name -Match $SearchGRP }

        #Compare l'arbo général avec les droits utilisateurs
        ForEach ($UserGroup in $UserGroups) {
            If ($Group.Name -eq $UserGroup.Name) {
                $Line | Add-Member -MemberType NoteProperty -Name $User.SamAccountName -Value true
            }
        }

        If (Get-Member -InputObject $Line -Name $User.SamAccountName) {}
        Else {
            $Line | Add-Member -MemberType NoteProperty -Name $User.SamAccountName -Value false
        }
    }
    $Line | Export-Csv -Path $PathContentFile -NoTypeInformation -Delimiter ';' -Append
}

#Contatène les fichiers entête et droits
New-Item -Path $Folder -Name $File -ItemType "file"
Add-Content -Path $PathFile -Value (Get-Content -Path $PathHeaderFile | Select-Object -Skip 1)
Remove-Item -Path $PathHeaderFile
Add-Content -Path $PathFile -Value (Get-Content -Path $PathEnabledFile | Select-Object -Skip 1)
Remove-Item -Path $PathEnabledFile
Add-Content -Path $PathFile -Value (Get-Content -Path $PathContentFile | Select-Object -Skip 1)
Remove-Item -Path $PathContentFile
Write-Host "End of Script!"
exit