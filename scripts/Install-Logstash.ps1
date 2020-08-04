Write-Formatted "Installing & conifiguring Logstash" -Level 0

try {
    $settings = (Get-Content .\settings.json -Raw) -join "`n" | ConvertFrom-Json -ErrorAction Stop
    $runFolder = "$($settings.runRootFolder)/$($settings.logstashConfig.folderName)/"
    $serviceName = $settings.logstashConfig.serviceName

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
    Write-Heading "Unzip Logstash ZIP file"
    "7z x $($settings.installationFilesFolder)/logstash-*.zip -y -aoa -o$($runFolder)" | Invoke-Expression
    #endregion

    $runFolder = (Resolve-Path "$($runFolder)/logstash*/").Path
    $logstashConfigPath = "$($runFolder)/config"
    $logstashServiceFolder = "$($runFolder)/service"

    Write-Formatted "Unzip location: `"$runFolder`"" -Level 0 -Mode SUCCESS
    Write-Formatted "Service location: `"$logstashServiceFolder`"" -Level 0 -Mode SUCCESS

    Write-Region -Text "Updating Logstash config file" -Level 0 -ForegroundColor "White"
    $configTemplate = (Get-Content .\Config-templates\Logstash\logstash-template.conf -Raw)
    $configTemplate = Replace-Text `
        -Text $configTemplate `
        -Replace "`${BEAT_PORT}" `
        -With $settings.logstashConfig.beatPort
    
    $configTemplate = Replace-Text `
        -Text $configTemplate `
        -Replace "`${ELASTICSEARCH_HOST:PORT}" `
        -With "$($settings.elasticSearchConfig.host):$($settings.elasticSearchConfig.port)"

    # backup existing config file
    if (Test-Path "$($logstashConfigPath)/logstash.conf" -PathType leaf) {

        Write-Heading "Backup existing [logstash.conf] file ($($logstashConfigPath)) before overrding it" -Level 0
        $backupFile = "$($logstashConfigPath)/logstash-backup-$(Get-Date -Format "dd-MM-yyyy_hh-mm-ss").conf"
        Copy-Item "$($logstashConfigPath)/logstash.conf" $backupFile -ErrorAction Stop -Force 
        Write-Formatted "Config backup file has been created: `"$backupFile`"" -Level 0 -Mode SUCCESS
    }

    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines("$($logstashConfigPath)/logstash.conf", $configTemplate, $Utf8NoBomEncoding)

    Write-Formatted "Config file has been created/update: $($logstashConfigPath)/logstash.conf" -Level 0 -Mode SUCCESS

    #region Unzip NSSM service app
    Write-Region -Text "Configuraing Logstash to run as Windows service"  -Level 0 -ForegroundColor "White"
    Write-Heading "Unzip NSSM service app"
    "7z x $($settings.installationFilesFolder)/nssm-*.zip -y -aoa -o$($logstashServiceFolder)" | Invoke-Expression
    Write-Heading "Moving zip file contnents to root directory - $($logstashServiceFolder)"
    Copy-Item -Recurse   "$($logstashServiceFolder)/nssm*/*" "$($logstashServiceFolder)/" -ErrorAction SilentlyContinue -Force
    Remove-Item -Path "$($logstashServiceFolder)/nssm*/" -Recurse
    Write-Formatted "Unzip location: `"$logstashServiceFolder`"" -Level 0 -Mode SUCCESS
    #endregion

    #region Configure and start NSSM
    Write-Heading "Configure and Install Logstash NSSM Service [$($serviceName)]"
    $nssmPath = "$($logstashServiceFolder)/win64"
    "$($nssmPath)/nssm.exe install $($serviceName) $($runFolder)/bin/logstash.bat" | Invoke-Expression -ErrorAction Stop

    "$($nssmPath)/nssm.exe set $($serviceName) AppParameters -f ""$($logstashConfigPath)/logstash.conf"" --http.host $($settings.logstashConfig.host) --http.port $($settings.logstashConfig.restApiPort)" | Invoke-Expression -ErrorAction Stop
    "$($nssmPath)/nssm.exe set $($serviceName) AppDirectory $($runFolder)/bin" | Invoke-Expression -ErrorAction Stop
    "$($nssmPath)/nssm.exe set $($serviceName) DisplayName ""Logstash Windows service""" | Invoke-Expression -ErrorAction Stop
    "$($nssmPath)/nssm.exe set $($serviceName) Start SERVICE_AUTO_START" | Invoke-Expression -ErrorAction Stop
    # "$($nssmPath)/nssm.exe set $($serviceName) DependOnService elasticsearch-service-x64" | Invoke-Expression -ErrorAction Stop

    "$($nssmPath)/nssm.exe start $($serviceName)" | Invoke-Expression -ErrorAction Stop

    Write-Formatted "[$($serviceName)] has been installed" -Level 0 -Mode SUCCESS
    #endregion

    #region Ensure that Logstash is up and running
    $logstashServiceUrl = "http://$($settings.logstashConfig.host):$($settings.logstashConfig.restApiPort)"
    Write-Formatted "Ensure that [$($serviceName)] is up and running"
    Write-Formatted "Logstash service URL: $($logstashServiceUrl)"
    Retry-Command -ScriptBlock { Invoke-RestMethod $logstashServiceUrl | Out-Null }  -Delay 15 -Maximum 10
    Write-Formatted "Logstash is up and running - URL: $($logstashServiceUrl)" -Level 0 -Mode SUCCESS
    #endregion

    # Write-Formatted "logstash is up and running - URL: $($kibanaServiceUrl)" -Level 0 -Mode SUCCESS
    Write-Heading "Logstash deployment Completed..."
}
catch {
    Write-Formatted $_.Exception.ToString() -Level 0 -Mode ERROR
    throw $PSItem
}

