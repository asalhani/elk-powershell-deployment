Write-Formatted "Installing & conifiguring Filebeat" -Level 0

try {
    $settings = (Get-Content .\settings.json -Raw) -join "`n" | ConvertFrom-Json -ErrorAction Stop
    $runFolder = "$($settings.runRootFolder)/$($settings.filebeatConfig.folderName)/"
    $serviceName = $settings.filebeatConfig.serviceName

    if (Get-Service $serviceName -ErrorAction SilentlyContinue) {
        If ((Get-Service $serviceName).Status -eq 'Running') {
            #stopping service
            Write-Formatted "Stopping Windows service $($serviceName)"
            Stop-Service $serviceName -ErrorAction Stop
            Write-Formatted "Windows service $($serviceName) Stopped" -Level 1 -Mode SUCCESS

            # remove windows service
            Write-Formatted "Removing Windows service $($serviceName)"
            Remove-Service -Name $serviceName 
            Write-Formatted "Windows service $($serviceName) Removed" -Level 1 -Mode SUCCESS
        }
    }

    #region Unzip Kibana ZIP file
    Write-Heading "Unzip Filebeat ZIP file"
    "7z x $($settings.installationFilesFolder)/Filebeat-*.zip -y -aoa -o$($runFolder)" | Invoke-Expression
    #endregion

    $runFolder = (Resolve-Path "$($runFolder)/filebeat*/").Path
    $FilebeatServiceFolder = "$($runFolder)/service"

    Write-Formatted "Unzip location: `"$runFolder`"" -Level 0 -Mode SUCCESS
    Write-Formatted "Service location: `"$FilebeatServiceFolder`"" -Level 0 -Mode SUCCESS

    Write-Region -Text "Updating Filebeat config file" -Level 0 -ForegroundColor "White"
    $configTemplate = (Get-Content .\Config-templates\filebeat\filebeat.template.yml -Raw)
    $configTemplate = Replace-Text `
        -Text $configTemplate `
        -Replace "`${INSPECTION_TENANTS_ROOT_LOGS}" `
        -With $settings.filebeatConfig.inspectionTenantsRootLogPath
    
    $configTemplate = Replace-Text `
        -Text $configTemplate `
        -Replace "`${ADMIN_PORTAL_ROOT_LOGS}" `
        -With "$($settings.filebeatConfig.adminPortalRootLogPath)"

    $configTemplate = Replace-Text `
        -Text $configTemplate `
        -Replace "`${LOGSTASH_HOST:PORT}" `
        -With "$($settings.logstashConfig.host):$($settings.logstashConfig.beatPort)"

    # backup existing config file
    $filebeatConfigPath = "$($runFolder)/filebeat.yml"
    if (Test-Path $filebeatConfigPath -PathType leaf) {

        Write-Heading "Backup existing [filebeat.yml] file ($($filebeatConfigPath)) before overrding it" -Level 0
        $backupFile = "$($filebeatConfigPath)-backup-$(Get-Date -Format "dd-MM-yyyy_hh-mm-ss")"
        Copy-Item $filebeatConfigPath $backupFile -ErrorAction Stop -Force 
        Write-Formatted "Config backup file has been created: `"$backupFile`"" -Level 0 -Mode SUCCESS
    }

    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines($filebeatConfigPath, $configTemplate, $Utf8NoBomEncoding)

    Write-Formatted "Config file has been created/update: $($filebeatConfigPath)" -Level 0 -Mode SUCCESS

    #region Unzip NSSM service app
    Write-Heading "Installing $($serviceName) windows service by running [install-service-filebeat.ps1] file" -Level 0
    $ScriptRoute = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($runFolder, "install-service-filebeat.ps1"))
    &"$ScriptRoute"
    Write-Formatted "$($serviceName) windows service has been installed" -Level 0 -Mode SUCCESS

    Write-Formatted "Starting $($serviceName) windows service" -Level 0 -Mode INFO
    Start-Service -Name $serviceName -ErrorAction Stop 
    Write-Formatted "[$($serviceName)] windows service has been started" -Level 0 -Mode SUCCESS

    #endregion

    # Write-Formatted "Filebeat is up and running - URL: $($kibanaServiceUrl)" -Level 0 -Mode SUCCESS
    Write-Heading "Filebeat deployment Completed..."
}
catch {
    Write-Formatted $_.Exception.ToString() -Level 0 -Mode ERROR
    throw $PSItem
}

