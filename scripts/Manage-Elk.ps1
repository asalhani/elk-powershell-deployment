$operation = Read-Host "Enter the operation you want to excute: [install] - [uninstall] - [stop] - [start]"

$ErrorActionPreferenceOriginalValue = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
# Default is Continue
Clear-Host
.\Copy-Module.ps1
.\Install-Prerequisites.ps1


$settings = (Get-Content .\settings.json -Raw) -join "`n" | ConvertFrom-Json -ErrorAction Stop
 
function Uninstall-Elasticsearch {
    Stop-and-Delete-Service -ServiceName $settings.elasticSearchConfig.serviceName
    Delete-Dir-Or-File -Path "$($settings.runRootFolder)/$($settings.elasticSearchConfig.folderName)"
}

function Uninstall-Kibana {
    Stop-and-Delete-Service -ServiceName $settings.kibanaConfig.serviceName 
    Delete-Dir-Or-File -Path "$($settings.runRootFolder)/$($settings.kibanaConfig.folderName)"
}

function Uninstall-Logstash {
    Stop-and-Delete-Service -ServiceName $settings.logstashConfig.serviceName
    Delete-Dir-Or-File -Path "$($settings.runRootFolder)/$($settings.logstashConfig.folderName)"
}

function Uninstall-Curator {
    $serviceName = $settings.curatorConfig.serviceName
    $task = Get-ScheduledTask -TaskName $serviceName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $serviceName  -Confirm:$false -ErrorAction Stop
        Write-Formatted "Schudeld task: [$($serviceName)] has been Removed" -Level 0 -Mode SUCCESS
    }
    else {
        Write-Formatted "Schudeld task: [$($serviceName)] Does not exist" -Level 0 -Mode DEBUG
    }
    Delete-Dir-Or-File -Path "$($settings.runRootFolder)/$($settings.curatorConfig.folderName)"
}

function Uninstall-Filebeat {
    Stop-and-Delete-Service -ServiceName $settings.fileBeatConfig.serviceName 
    Delete-Dir-Or-File -Path "$($settings.runRootFolder)/$($settings.fileBeatConfig.folderName)"
}

function Print-Components-to-Uninstall {
    Write-Formatted "Components to Uninstall:"
    $oneServiceToBeInstalled = $false

    if ($settings.uninstallElkConfig.UninstallElasticsearch) {
        Write-Formatted "Elasticsearch" -Level 1 -Mode INFO
        $oneServiceToBeInstalled = $true
    }

    if ($settings.uninstallElkConfig.UninstallLogstash) {
        Write-Formatted "Logstash" -Level 1 -Mode INFO
        $oneServiceToBeInstalled = $true
    }

    if ($settings.uninstallElkConfig.UninstallKibana) {
        Write-Formatted "Kibana" -Level 1 -Mode INFO
        $oneServiceToBeInstalled = $true
    }

    if ($settings.uninstallElkConfig.UninstallCurator) {
        Write-Formatted "Elasticsearch Curator" -Level 1 -Mode INFO
        $oneServiceToBeInstalled = $true
    }

    if ($settings.uninstallElkConfig.UninstallFilebeat) {
        Write-Formatted "Filebeat" -Level 1 -Mode INFO
        $oneServiceToBeInstalled = $true
    }

    if (!$oneServiceToBeInstalled) {
        Write-Formatted "No componentes has been marked to unistall. Check the Settings.josn file ==> [uninstallElkConfig] section" -Level 1 -Mode DEBUG
    }
}

function Uninstall-Elk {
    Write-Heading "Uninstalling ELK"
    
    Print-Components-to-Uninstall

    if ($settings.uninstallElkConfig.UninstallKibana) {
        Uninstall-Kibana
    }

    if ($settings.uninstallElkConfig.UninstallLogstash) {
        Uninstall-Logstash
    }

    if ($settings.uninstallElkConfig.UninstallCurator) {
        Uninstall-Curator
    }

    if ($settings.uninstallElkConfig.UninstallFilebeat) {
        Uninstall-Filebeat
    }

    if ($settings.uninstallElkConfig.UninstallElasticsearch) {
        Uninstall-Elasticsearch
    }
}

function Install-Elk-Stack {
    Write-Heading "Installing ELK"

    .\Install-Elasticsearch.ps1
    .\Install-Kibana.ps1
    .\Install-Logstash.ps1
    .\Install-elasticsearch-curator.ps1
    .\Install-Filebeat.ps1
}

function Stop-Elk-Stack {
    Write-Heading "Stopping ELK"
    
    Stop-Windows-Service -ServiceName $settings.fileBeatConfig.serviceName
    Stop-Windows-Service -ServiceName $settings.kibanaConfig.serviceName
    Stop-Windows-Service -ServiceName $settings.curatorConfig.serviceName
    Stop-Windows-Service -ServiceName $settings.elasticSearchConfig.serviceName
    Stop-Windows-Service -ServiceName $settings.logstashConfig.serviceName

    exit
}

function Start-Elk-Stack {
    Write-Heading "Starting ELK"
    
    Start-Windows-Service -ServiceName $settings.logstashConfig.serviceName
    Start-Windows-Service -ServiceName $settings.fileBeatConfig.serviceName
    Start-Windows-Service -ServiceName $settings.kibanaConfig.serviceName
    Start-Windows-Service -ServiceName $settings.curatorConfig.serviceName
    Start-Windows-Service -ServiceName $settings.elasticSearchConfig.serviceName
    
    exit
}


## program start from here
try {
    
    if ($operation -eq "uninstall") {
        Uninstall-Elk
        exit
    }

    if ($operation -eq "install") {
        Install-Elk-Stack
        exit
    }

    if ($operation -eq "stop") {
        Stop-Elk-Stack
        exit
    }

    if ($operation -eq "start") {
        Start-Elk-Stack
        exit
    }
    
}
catch {
    Write-Formatted $_.Exception.ToString() -Level 0 -Mode ERROR
    throw $PSItem
}

