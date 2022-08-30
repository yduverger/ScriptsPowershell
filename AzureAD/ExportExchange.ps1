#Find-Module Microsoft.Graph*

##Installation des Modules utiles
#Install-Module Microsoft.Graph -Scope CurrentUser
#Select-MgProfile -Name "v1.0"

Connect-AzureAD
Connect-Graph -Scopes User.Read.All, Organization.Read.All

#Code Client
#$CodeClient = "CODE"
$CodeClient = Read-Host -Prompt "Entrer le code client"

#Variables d'environment
$Date = Get-Date -Format "yyyyMMddHHmm"
#$Folder = "C:\Users\%user%\Desktop\ExportExchange\"
$Folder = Read-Host -Prompt "Chemin du dossier de travail"
$FolderTmp = $Folder + "TMP\"
$File = $Date + "_" + $CodeClient + "_ExportExhange.csv"
$PathFile = $Folder + $File

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

$Users = Get-AzureADUser -All $true
$UsersList = $Users | 
    Select-Object -Property UserPrincipalName, Mail, DisplayName, CompanyName, ObjectType, AccountEnabled, ShowInAddressList
##Where-Object {$_.ObjectType -eq "User" -and $_.AccountEnabled -eq $true -and $_.CompanyName -like 'ensol*'}
Write-Host $UsersList

$Licenses = Get-AzureADSubscribedSku
$LicensesList = $Licenses | 
    Select SkuPartNumber, ConsumedUnits
#Write-Host $LicensesList

ForEach ($User in $UsersList) {
    $UserPrincipalName = $($User.UserPrincipalName)
    $Licence = Get-MgUserLicenseDetail -UserId $UserPrincipalName
    if ([string]::IsNullOrEmpty($Licence.SkuPartNumber)) {
        $LicenceName = ''
    } else {
        $LicenceName = [String]::Join(',',$Licence.SkuPartNumber)
    }
        
    $User | Add-Member -MemberType NoteProperty -Name SkuPartNumber -Value $LicenceName
    $User | Export-Csv -Path $PathFile -NoTypeInformation -Delimiter ';' -Append
}


#$AllSku = Get-MgSubscribedSku -Property SkuPartNumber, ServicePlans, ConsumedUnits
#Write-Host $AllSku

#$AllSku | ForEach-Object {
#    Write-Host "Service Plan:" $_.SkuPartNumber
#    $_.ServicePlans | ForEach-Object {$_}
#}

Disconnect-AzureAD
Write-Host "End of Script!"
exit