Write-Formatted "Installing & conifiguring ElasticSearch" -Level 0

try {
    $settings = (Get-Content .\settings.json -Raw) -join "`n" | ConvertFrom-Json -ErrorAction Stop
    $runFolder = "$($settings.runRootFolder)/$($settings.elasticSearchConfig.folderName)/"
    $serviceName = $settings.elasticSearchConfig.serviceName

    if (Get-Service $serviceName -ErrorAction SilentlyContinue) {
        If ((Get-Service $serviceName).Status -eq 'Running') {
            #stopping service
            Write-Formatted "Stopping Windows service $($serviceName)"
            Stop-Service $serviceName -ErrorAction Stop
            Write-Formatted "Windows service $($serviceName) Stopped" -Level 0 -Mode SUCCESS
        }
    }

    # unzip elasticsearch zip file 

    $settings.installationFilesFolder
    $runFolder
    Write-Heading "Unzip ElasticSearch ZIP file"
    "7z x $($settings.installationFilesFolder)/elasticsearch-*.zip -y -aoa -o$($runFolder)" | Invoke-Expression
    $runFolder = (Resolve-Path "$($runFolder)/elasticsearch*/").Path
    Write-Formatted "Unzip location: `"$runFolder`"" -Level 0 -Mode SUCCESS

    # Install ElasticSearch windows service
    Write-Heading "Install ElasticSearch Windows service"
    if (Get-Service $serviceName -ErrorAction SilentlyContinue) {
        If ((Get-Service $serviceName).Status -eq 'Running' -or 'Stopped') {
            
            Write-Formatted "Stopping Windows service $($serviceName)"
            Stop-Service -Name $serviceName -Force
            Write-Formatted "Windows service $($serviceName) Stopped" -Level 0 -Mode SUCCESS

            #remove service
            Write-Formatted "Removing Windows service $($serviceName)"
            Remove-Service -Name $serviceName
            Write-Formatted "Windows service $($serviceName) Removed" -Level 0 -Mode SUCCESS
        }
    }

    # install service
    Write-Formatted "Installing Windows service $($serviceName)"
    "$($runFolder)/bin/elasticsearch-service.bat install" | Invoke-Expression -ErrorAction Stop
    Write-Formatted "Elasticsearch Windows service installed" -Level 0 -Mode SUCCESS

    #Update service startup type
    Write-Formatted "Updating start type of Windows service $($serviceName)"
    Set-Service -Name $serviceName -StartupType Automatic -ErrorAction Stop
    Write-Formatted "Elasticsearch  Windows service start type updated" -Level 0 -Mode SUCCESS

    #start service
    Write-Formatted "Installing Windows service $($serviceName)"
    "$($runFolder)/bin/elasticsearch-service.bat start" | Invoke-Expression -ErrorAction Stop
    Write-Formatted "Elasticsearch Windows service started" -Level 0 -Mode SUCCESS

    # Ensure that ElasticSearch is up and running
    $elasticSearchUrl = "http://$($settings.elasticSearchConfig.host):$($settings.elasticSearchConfig.port)"
    Write-Formatted "Ensure that ElasticSearch is up and running"
    Write-Formatted "Elasticsearch service URL: $($elasticSearchUrl)"
    Retry-Command -ScriptBlock { Invoke-RestMethod $elasticSearchUrl }  -Delay 5 -Maximum 5
    Write-Formatted "Elasticsearch is up and running - URL: $($elasticSearchUrl)" -Level 0 -Mode SUCCESS
}
catch {
    Write-Formatted $_.Exception.ToString() -Level 0 -Mode ERROR
    throw $PSItem
}