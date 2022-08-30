#Code Client
$CodeClient = "CODE"

#OverrideMode (C,M,D)
$OverrideMode = "M"

#Variable de recherche utilisateurs dans l'AD
$SearchOU = 
"OU=OU1,OU=Users,OU=MyBusiness,DC=DOMAIN,DC=LOCAL",
"OU=OU2,OU=Users,OU=MyBusiness,DC=DOMAIN,DC=LOCAL"

$SearchGRP = "_(R|RXW)$"

#Variables d'environment
$Date = Get-Date -Format "yyyyMMddHHmm"
$Folder = "C:\Users\%user%\Desktop\ExportAD\"
$FolderTmp = $Folder + "TMP\"
$File = $Date + "_PS1_ADGroupMembership.txt"
$PathFile = $Folder + $File

#Récupère les utilisateurs de l'AD
$Users = $SearchOU | ForEach { Get-ADUser -Filter * -Properties * -SearchBase $_ } | Select-Object UserPrincipalName, SamAccountName, Name, LastLogonDate, Enabled | Sort Enabled, Name
#Récupère la liste des groupes de sécurité (arborescence)
$GroupsList = Get-ADGroup -Filter * | Select-Object Name | Where-Object {$_.Name -Match $SearchGRP } | Sort Name

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

#Crée le fichier d'entête
$HeaderFile = "00.tmp"
New-Item -Path $FolderTmp -Name $HeaderFile -ItemType "file"
$PathHeaderFile = $FolderTmp + $HeaderFile

#Crée le fichier utilisateurs AD
$UsersFile = "01.tmp"
New-Item -Path $FolderTmp -Name $UsersFile -ItemType "file"
$PathUsersFile = $FolderTmp + $UsersFile

#Crée le fichier des droits arborescence
$GroupsFile = "03.tmp"
New-Item -Path $FolderTmp -Name $GroupsFile -ItemType "file"
$PathGroupsFile = $FolderTmp + $GroupsFile

#Initie les données d'entête
$Line = New-Object -TypeName psobject
$Line | Add-Member -MemberType NoteProperty -Name Line -Value "00"
$Line | Add-Member -MemberType NoteProperty -Name Client -Value $CodeClient
$Line | Add-Member -MemberType NoteProperty -Name Interface -Value "AD"
$Line | Add-Member -MemberType NoteProperty -Name Mode -Value $OverrideMode
$Line | Export-Csv -Path $PathHeaderFile -NoTypeInformation -Delimiter ';'

#Parcours tous les utilisateurs
ForEach ($User in $Users) {
    #Initie les données utilisateurs
    ($User | Select-Object @{Name="Line";Expression={"01"}},*) | Export-Csv -Path $PathUsersFile -NoTypeInformation -Delimiter ';' -Append

    #Récupère les droits arbo de l'utilisateur
    $UserGroups = Get-ADPrincipalGroupMembership $($User.SamAccountName) | Select-Object Name | Sort Name | Where-Object { $_.Name -Match $SearchGRP }
   
    #Compare l'arbo général avec les droits utilisateurs
    ForEach ($Group in $GroupsList) {
        #Initie les données droits arbo
        $Line = New-Object -TypeName psobject
        $Line | Add-Member -MemberType NoteProperty -Name Line -Value "03"
        $Line | Add-Member -MemberType NoteProperty -Name UserPrincipalName -Value $User.UserPrincipalName
        $Line | Add-Member -MemberType NoteProperty -Name GroupName -Value $Group.Name
        
        ForEach ($UserGroup in $UserGroups) {
            If ($Group.Name -eq $UserGroup.Name) {
                $Line | Add-Member -MemberType NoteProperty -Name Enabled -Value true
            }
        }

        If (Get-Member -InputObject $Line -Name Enabled) {}
        Else {
            $Line | Add-Member -MemberType NoteProperty -Name Enabled -Value false
        } 
        $Line | Export-Csv -Path $PathGroupsFile -NoTypeInformation -Delimiter ';' -Append
    }
}

#Contatène les fichiers entête, utilisateurs et droits
New-Item -Path $Folder -Name $File -ItemType "file"
Add-Content -Path $PathFile -Value (Get-Content -Path $PathHeaderFile | Select-Object -Skip 1)
Remove-Item -Path $PathHeaderFile
Add-Content -Path $PathFile -Value (Get-Content -Path $PathUsersFile | Select-Object -Skip 1)
Remove-Item -Path $PathUsersFile
Add-Content -Path $PathFile -Value (Get-Content -Path $PathGroupsFile | Select-Object -Skip 1)
Remove-Item -Path $PathGroupsFile
Write-Host "End of Script!"
exit