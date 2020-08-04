Write-Formatted "Installing & conifiguring kibana" -Level 0

try {
    $settings = (Get-Content .\settings.json -Raw) -join "`n" | ConvertFrom-Json -ErrorAction Stop
    $runFolder = "$($settings.runRootFolder)/$($settings.kibanaConfig.folderName)/"
    $serviceName = $settings.kibanaConfig.serviceName

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
    Write-Heading "Unzip kibana ZIP file"
    "7z x $($settings.installationFilesFolder)/kibana-*.zip -y -aoa -o$($runFolder)" | Invoke-Expression
    Write-Heading "Moving zip file contnents to root directory - $($runFolder)"
    Write-Formatted "Unzip location: `"$runFolder`"" -Level 0 -Mode SUCCESS
    #endregion

    $runFolder = (Resolve-Path "$($runFolder)/kibana*/").Path
    $kibanaServiceFolder = "$($runFolder)/service"
    $kibanaYamlConfigPath = "$($runFolder)/config/kibana.yml"

    Write-Region -Text "Updating Kibana config file: `n $(Get-Tabs 2) $($kibanaYamlConfigPath)"  -Level 0 -ForegroundColor "White"

    [string[]]$kibanaYamlConfigFileContent = Get-Content $kibanaYamlConfigPath
    $content = ''
    foreach ($line in $kibanaYamlConfigFileContent) { 
        $content = $content + "`n" + $line 
    }
    $yaml = ConvertFrom-YAML $content

    # intilize $yaml var. in case the document is empty
    if (!$yaml) {
        $yaml = @{}
    }

    Write-Formatted "Kibana config file has been loaded ($($kibanaYamlConfigPath))" -Level 0 -Mode SUCCESS
    Write-Formatted  (ConvertTo-Yaml $yaml) -Level 0 -Mode SUCCESS

    #region intilize Kibana config
    #region [server.port]
    if ($yaml.ContainsKey("server.port")) {
        $yaml.Remove("server.port")
    }
    $yaml.Add("server.port", $settings.kibanaConfig.port)
    #endregion

    #region [server.host]
    $serverHost = ""
    if ($yaml.ContainsKey("server.host")) {
        $yaml.Remove("server.host")
    }
    $yaml.Add("server.host", $settings.kibanaConfig.host)
    #endregion
    
    #region [elasticsearch.hosts]
    if ($yaml.ContainsKey("elasticsearch.hosts")) {
        $yaml.Remove("elasticsearch.hosts")
    }
    $elasticSearchHost = "http://$($settings.elasticSearchConfig.host):$($settings.elasticSearchConfig.port)"
    $hostsList = New-Object Collections.Generic.List[String]
    $hostsList.Add($elasticSearchHost)
    $yaml.Add("elasticsearch.hosts", $hostsList)
    #endregion
    #endregion

    #region backup current [kibana.yml] before overrideing it
    Write-Heading "Backup existing [kibana.yml] file ($($kibanaYamlConfigPath)) before overrding it" -Level 0
    $backupFile = "$($runFolder)/config/kibana-backup-$(Get-Date -Format "dd-MM-yyyy_hh-mm-ss").yml"
    Copy-Item $kibanaYamlConfigPath $backupFile -ErrorAction Stop -Force 
    Write-Formatted "Config backup file has been created: `"$backupFile`"" -Level 0 -Mode SUCCESS
    #endregion

    # update kibana.yml file with the new config. values
    ConvertTo-Yaml $yaml -OutFile $kibanaYamlConfigPath -Force 
 
    # run Kibana as Windws service

    #region Unzip NSSM service app
    Write-Region -Text "Configuraing Kibana to run as Windows service"  -Level 0 -ForegroundColor "White"
    Write-Heading "Unzip NSSM service app"
    "7z x $($settings.installationFilesFolder)/nssm-*.zip -y -aoa -o$($kibanaServiceFolder)" | Invoke-Expression
    Write-Heading "Moving zip file contnents to root directory - $($kibanaServiceFolder)"
    Copy-Item -Recurse   "$($kibanaServiceFolder)/nssm*/*" "$($kibanaServiceFolder)/" -ErrorAction SilentlyContinue -Force
    Remove-Item -Path "$($kibanaServiceFolder)/nssm*/" -Recurse
    Write-Formatted "Unzip location: `"$kibanaServiceFolder`"" -Level 0 -Mode SUCCESS
    #endregion

    #region Configure and start NSSM
    Write-Heading "Configure and Install Kibana NSSM Service [$($serviceName)]"
    $nssmPath = "$($kibanaServiceFolder)/win64"
    "$($nssmPath)/nssm.exe install $($serviceName) $($runFolder)/bin/kibana.bat" | Invoke-Expression -ErrorAction Stop

    "$($nssmPath)/nssm.exe set $($serviceName) AppDirectory $($runFolder)/bin" | Invoke-Expression -ErrorAction Stop
    "$($nssmPath)/nssm.exe set $($serviceName) DisplayName ""Kibana Windows service""" | Invoke-Expression -ErrorAction Stop
    "$($nssmPath)/nssm.exe set $($serviceName) Start SERVICE_AUTO_START" | Invoke-Expression -ErrorAction Stop
    "$($nssmPath)/nssm.exe set $($serviceName) DependOnService elasticsearch-service-x64" | Invoke-Expression -ErrorAction Stop

    "$($nssmPath)/nssm.exe start $($serviceName)" | Invoke-Expression -ErrorAction Stop

    Write-Formatted "[$($serviceName)] has been installed" -Level 0 -Mode SUCCESS
    #endregion

    #region Ensure that Kibana is up and running
    $kibanaServiceUrl = "http://$($settings.kibanaConfig.host):$($settings.kibanaConfig.port)"
    Write-Formatted "Ensure that [$($serviceName)] is up and running"
    Write-Formatted "Kibana service URL: $($kibanaServiceUrl)"
    Retry-Command -ScriptBlock { Invoke-RestMethod $kibanaServiceUrl | Out-Null }  -Delay 15 -Maximum 5
    Write-Formatted "Kibana is up and running - URL: $($kibanaServiceUrl)" -Level 0 -Mode SUCCESS
    #endregion

    Write-Formatted "Kibana is up and running - URL: $($kibanaServiceUrl)" -Level 0 -Mode SUCCESS
    Write-Heading "Kibana deployment Completed..."
}
catch {
    Write-Formatted $_.Exception.ToString() -Level 0 -Mode ERROR
    throw $PSItem
}

