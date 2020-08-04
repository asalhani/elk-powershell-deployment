Write-Region "Checking Prerequisites"

Write-Heading "Installing Chocolatey"
$chocoIsInstalledCheckCmd = Invoke-Expression "choco --version"
$chocoIsInstalled = $null -ne $chocoIsInstalledCheckCmd
if (!($chocoIsInstalled)) { 
    Write-Formatted "Installing Chocolatey" -Level 1   
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    Write-Formatted "Refreshing environment variables" -Level 1
    "refreshenv" | Invoke-Expression
}
else {
    Write-Formatted "Chocolatey is already installed. No action needed" -Level 1
}

Write-Heading "Installing 7-Zip"
$dotnetIsInstalledCheckCmd = Invoke-Expression "7z version"
$dotnetIsInstalled = $null -ne $dotnetIsInstalledCheckCmd
if (!($dotnetIsInstalled)) {
    Write-Formatted "Installing 7-Zip" -Level 1
    "choco install 7zip -y" | Invoke-Expression
    Write-Formatted "Refreshing environment variables" -Level 1
    "refreshenv" | Invoke-Expression
}
else {
    Write-Formatted "7-Zip is already installed. No action needed" -Level 1
}

Write-Heading "Installing Java Runtime"
$dotnetIsInstalledCheckCmd = Invoke-Expression "java -version"
$dotnetIsInstalled = $null -ne $dotnetIsInstalledCheckCmd
if (!($dotnetIsInstalled)) {
    Write-Formatted "Installing Java Runtime" -Level 1
    "choco install javaruntime -y" | Invoke-Expression
    Write-Formatted "Refreshing environment variables" -Level 1
    "refreshenv" | Invoke-Expression
}
else {
    Write-Formatted "Java Runtime is already installed. No action needed" -Level 1
}

Write-Heading "Installing Carbon Module"
$carbonModule = Get-Module -Listavailable -Name Carbon
if ($null -eq $carbonModule) {
    Write-Formatted "Trusting Powershell Gallery" -Level 1
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
    Write-Formatted "Downloading and installing Carbon from Powershell Gallery" -Level 1
    Install-Module -Name Carbon
    Write-Formatted "Importing Carbon Module" -Level 1
    Import-Module Carbon
}
