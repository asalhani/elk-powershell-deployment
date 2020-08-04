$destination = "$home\Documents\WindowsPowerShell\"
#Write-Host "Checking whether destination `"$destination`" exists"
$destinationExists = Test-Path $destination -PathType Container
If ($destinationExists -eq $false)
{
    #Write-Host "Destination `"$destination`" does not exist. Attempting to create ..."
    New-Item "$home\Documents\WindowsPowerShell\" -ItemType Container
    #Write-Host "Destination `"$destination`" created"
}
else 
{
    #Write-Host "Destination `"$destination`" already exists"
}
#Write-Host "Copying Powershell Module `"PlatformHelperFunctions`" to `"$destination`""

#Copy-Item .\Modules\PlatformHelperFunctions\PlatformHelperFunctions.psm1 -Destination $destination -Force
Copy-Item .\Modules\ -Destination $destination -Recurse -Force

#Write-Host "Powershell Module `"PlatformHelperFunctions`" has been copied to `"$destination`""
Import-Module PlatformHelperFunctions -Force -Global
Import-Module powershell-yaml -Force -Global
