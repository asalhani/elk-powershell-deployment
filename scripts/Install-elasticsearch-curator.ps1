Write-Formatted "Installing & conifiguring Curator" -Level 0

try {
    $settings = (Get-Content .\settings.json -Raw) -join "`n" | ConvertFrom-Json -ErrorAction Stop
    $runFolder = "$($settings.runRootFolder)/$($settings.curatorConfig.folderName)/"
    $serviceName = $settings.curatorConfig.serviceName

    #region Unzip Curator ZIP file
    Write-Heading "Unzip Curator ZIP file"
    "7z x $($settings.installationFilesFolder)/elasticsearch-curator-*.zip -y -aoa -o$($runFolder)" | Invoke-Expression
    #endregion

    $runFolder = (Resolve-Path "$($runFolder)/curator*/").Path
    $CuratorServiceFolder = "$($runFolder)/service"

    Write-Formatted "Unzip location: `"$runFolder`"" -Level 0 -Mode SUCCESS
    Write-Formatted "Service location: `"$CuratorServiceFolder`"" -Level 0 -Mode SUCCESS

    Write-Region -Text "Updating Curator config file" -Level 0 -ForegroundColor "White"
    $configTemplate = (Get-Content .\Config-templates\Curator\curator-config.template.yml -Raw -ErrorAction Stop) -join "`n"

    Write-Formatted "Replacing config. var. `${ELASTICSEARCH_HOST} = $($settings.elasticSearchConfig.host)" -Level 0 -Mode INFO
    $configTemplate = Replace-Text `
        -Text $configTemplate `
        -Replace "`${ELASTICSEARCH_HOST}" `
        -With $settings.elasticSearchConfig.host
    
    Write-Formatted "Replacing config. var. `${ELASTICSEARCH_PORT} = $($settings.elasticSearchConfig.port)" -Level 0 -Mode INFO
    $configTemplate = Replace-Text `
        -Text $configTemplate `
        -Replace "`${ELASTICSEARCH_PORT}" `
        -With "$($settings.elasticSearchConfig.port)"

    Write-Formatted "Replacing config. var. `${LOG_PATH} = $($settings.curatorConfig.logging.logFile)" -Level 0 -Mode INFO
    $configTemplate = Replace-Text `
        -Text $configTemplate `
        -Replace "`${LOG_PATH}" `
        -With "$($settings.curatorConfig.logging.logFile)"

    Write-Formatted "Replacing config. var. `${LOG_LEVEL} = $($settings.curatorConfig.logging.logLevel)" -Level 0 -Mode INFO
    $configTemplate = Replace-Text `
        -Text $configTemplate `
        -Replace "`${LOG_LEVEL}" `
        -With "$($settings.curatorConfig.logging.logLevel)"

    # backup existing config file
    $curatorConfigFile = "$($runFolder)/curator-config.yml"
    if (Test-Path $curatorConfigFile -PathType leaf) {
        Write-Heading "Backup existing  file [$($curatorConfigFile)] before overrding it" -Level 0
        $backupFile = "$($runFolder)/curator-config-backup-$(Get-Date -Format "dd-MM-yyyy_hh-mm-ss").conf"
        Copy-Item "$($curatorConfigFile)" $backupFile -ErrorAction Stop -Force 
        Write-Formatted "Config backup file has been created: `"$backupFile`"" -Level 0 -Mode SUCCESS
    }
    $configTemplate | Out-File "$($curatorConfigFile)"
    Write-Formatted "Config file has been created/update: $($curatorConfigFile)" -Level 0 -Mode SUCCESS

    #region Copy [delete-old-indices.yml] file
    Write-Region -Text "Updating Curator delete indices config file" -Level 0 -ForegroundColor "White"
    $configTemplate = (Get-Content .\Config-templates\Curator\delete-old-indices.template.yml -Raw -ErrorAction Stop) -join "`n"

    $oldIndicesConfigFile = "$($runFolder)/delete-old-indices.yml"
    if (Test-Path $oldIndicesConfigFile -PathType leaf) {
        Write-Heading "Backup existing  file [$($oldIndicesConfigFile)] before overrding it" -Level 0
        $backupFile = "$($runFolder)/delete-old-indices-$(Get-Date -Format "dd-MM-yyyy_hh-mm-ss").conf"
        Copy-Item "$($oldIndicesConfigFile)" $backupFile -ErrorAction Stop -Force 
        Write-Formatted "Config backup file has been created: `"$backupFile`"" -Level 0 -Mode SUCCESS
    }
    $configTemplate | Out-File "$($oldIndicesConfigFile)"
    Write-Formatted "Delete old indices file has been created/update: $($oldIndicesConfigFile)" -Level 0 -Mode SUCCESS

    #endregion

    #region Configure and start Curator scheduled task
    Write-Heading "Configure and Install Curator scheduled task [$($serviceName)]"
    Get-ScheduledTask -TaskName $serviceName -ErrorAction SilentlyContinue -OutVariable task

    if($task){
        Unregister-ScheduledTask -TaskName $serviceName -Confirm:$false -ErrorAction Stop
    }

    $action = New-ScheduledTaskAction `
        -Execute "curator.exe" `
        -WorkingDirectory $runFolder `
        -Argument "--config ""$($curatorConfigFile)"" ""$($oldIndicesConfigFile)""" `
        -Id $serviceName 

    $trigger = New-ScheduledTaskTrigger `
        -Daily `
        -At 2am
    
    Register-ScheduledTask `
        -Action $action `
        -Trigger $trigger `
        -TaskName $serviceName `
        -Description   "Elasticsearch Curtor task" `
        -Force `
        -ErrorAction Stop 

    Write-Formatted "[$($serviceName)] scheduled task has been installed" -Level 0 -Mode SUCCESS

    Start-ScheduledTask -TaskName $serviceName
    Write-Formatted "[$($serviceName)] scheduled task has been started" -Level 0 -Mode SUCCESS
    #endregion

    Write-Heading "Curator deployment Completed..."
}
catch {
    Write-Formatted $_.Exception.ToString() -Level 0 -Mode ERROR
    throw $PSItem
}

