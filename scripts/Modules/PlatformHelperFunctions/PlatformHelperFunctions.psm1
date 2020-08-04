function Replace-Text
{
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Text,
        [Parameter(Mandatory=$true, Position=1)]
        [string]$Replace,
        [Parameter(Mandatory=$true, Position=2)]
        [string]$With
    )
    return [Regex]::Replace($Text,[regex]::Escape($Replace),$With,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase);
}

function Get-IpAddressValue
{
    $ipAddress = Get-NetIPAddress -AddressFamily IPv4 | ? {$_.PrefixOrigin -eq "Dhcp"} | Select IPAddress
    return $ipAddress.IPAddress
}

function Replace-FileContent
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$ConfigFile,
        [Parameter(Mandatory=$false, Position=1)]
        [string]$SettingEnvironment
    )
    $ipAddress = Get-IpAddressValue
    Write-Region -Text "Starting File Replacements process" -Level 0
    Write-Formatted -Message "Setting Environment: $SettingEnvironment" -Mode INFO -Level 0
    Write-Formatted -Message "Config File: $ConfigFile" -Mode INFO -Level 0
    $settingssFile = (Get-Content $ConfigFile) -join "`n" | ConvertFrom-Json
    $files = $settingssFile.settings.files
    $globalReplacements = $settingssFile.settings.global_replacements
    $replacementsCount = 0
    if ($globalReplacements)
    {
        $replacementsCount = $globalReplacements.Count
    }
    $filesCount = $files.Count
    $baseDirectory = $pwd
    Write-Formatted -Message "Updating $filesCount Targets" -Mode INFO -Level 1
    Write-Host
    $globalCounter = 1
    foreach($file in $files)
    {
        $targetFile = $file.file
        $fileReplacements = $file.replacements
        Write-Region -Text "$globalCounter/$filesCount - File `'$targetFile`'" -Level 1
        Write-Formatted "Updating file `'$targetFile`' name if it contains #ENVIRONMENT# flags" -Mode INFO -Level 1
        $targetFile = Replace-Text $targetFile "#ENVIRONMENT#" $SettingEnvironment
        $targetFileFullPath = "$baseDirectory\$targetFile" 
        Write-Formatted "Updating `"$targetFileFullPath`"" -Mode INFO -Level 1
        Write-Formatted "Checking whether Target file `"$targetFileFullPath`" exists" -Mode INFO -Level 1
        $fileExists = [System.IO.File]::Exists($targetFileFullPath)
        if ($fileExists -eq $True)
        {
            $targetFileFullPath = Resolve-Path $targetFileFullPath
            Write-Formatted "Target file `"$targetFileFullPath`" already exists" -Mode INFO -Level 1
            $backupFileName = Get-BackupFileName $targetFileFullPath
            $oldTargetFileContent = Get-Content $targetFileFullPath
            $targetFileFileContent = $oldTargetFileContent

            $foundOldValues = $false
            Write-Host
            Write-Region -Text "Applying $replacementsCount global replacements" -Level 2
            $replacementsCounter = 1
            foreach($globalReplacement in $globalReplacements)
            {
                $old = $globalReplacement.old.ToString()
                $old = $old -replace "{DYNAMIC_IP_ADDRESS}", $ipAddress
                $new = $globalReplacement.new.ToString()
                $new = $new -replace "{DYNAMIC_IP_ADDRESS}", $ipAddress
                $old = [Regex]::Replace($old,[regex]::Escape("#ENVIRONMENT#"),$SettingEnvironment,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase);
                $new = [Regex]::Replace($new,[regex]::Escape("#ENVIRONMENT#"),$SettingEnvironment,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase);
                #$old = Replace-Text $old "#ENVIRONMENT#" $SettingEnvironment
                #$new = Replace-Text $new "#ENVIRONMENT#" $SettingEnvironment
                Write-Formatted "$replacementsCounter/$replacementsCount Looking for `"$old`" to be replaced with `"$new`"" -Mode INFO -Level 2
                If (Select-String -Path $targetFileFullPath -Pattern $old)
                {
                    Write-Formatted "Found matching replacement" -Mode SUCCESS -Level 2
                    #$targetFileFileContent = Replace-Text $targetFileFileContent $old $new
                    $targetFileFileContent = [Regex]::Replace($targetFileFileContent,[regex]::Escape($old),$new,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase);
                    $foundOldValues = $true
                }
                else
                {
                    Write-Formatted "Did not find a matching replacement" -Mode INFO -Level 2
                }  
                $replacementsCounter++
                Write-Host           
            }

            Write-Host
            Write-Host

            $fileReplacementsCount = 0
            if ($fileReplacements)
            {
                $fileReplacementsCount = $fileReplacements.Count
            }
            Write-Region -Text "Applying $fileReplacementsCount local replacements" -Level 2
            $fileReplacementsCounter = 1
            foreach($fileReplacement in $fileReplacements)
            {
                $old = $fileReplacement.old.ToString()
                $old = $old -replace "{DYNAMIC_IP_ADDRESS}", $ipAddress
                $new = $fileReplacement.new.ToString()
                $new = $new -replace "{DYNAMIC_IP_ADDRESS}", $ipAddress
                #$old = Replace-Text $old "#ENVIRONMENT#" $SettingEnvironment
                #$new = Replace-Text $new "#ENVIRONMENT#" $SettingEnvironment
                $old = [Regex]::Replace($old,[regex]::Escape("#ENVIRONMENT#"),$SettingEnvironment,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase);
                $new = [Regex]::Replace($new,[regex]::Escape("#ENVIRONMENT#"),$SettingEnvironment,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase);
                Write-Formatted "$fileReplacementsCounter/$fileReplacementsCount Looking for `"$old`" to be replaced with `"$new`"" -Mode INFO -Level 2
                If (Select-String -Path $targetFileFullPath -Pattern $old)
                {
                    Write-Formatted "Found matching replacement" -Mode SUCCESS -Level 2
                    #$targetFileFileContent = Replace-Text $targetFileFileContent $old $new
                    $targetFileFileContent = [Regex]::Replace($targetFileFileContent,[regex]::Escape($old),$new,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase);
                    $foundOldValues = $true
                }
                else
                {
                    Write-Formatted "Did not find a matching replacement" -Mode INFO -Level 2
                }  
                $fileReplacementsCounter++
                Write-Host           
            }


            If ($foundOldValues -eq $true)
            {
                Write-Formatted "creating a backup to $backupFileName" -Mode INFO -Level 1
                $oldTargetFileContent > $backupFileName
                Write-Formatted "Saving changes to disk ...." -Mode INFO -Level 1
                $targetFileFileContent > $targetFileFullPath
            }
            else
            {
               Write-Formatted "Nothing found to change ...." -Mode INFO -Level 1
            }

        }
        else
        {
            Write-Formatted -Message "Target file `"$targetFileFullPath`" does not exist" -Mode "ERROR" -Level 1
        }
        Write-EndingLine -Level 1
        Write-Host
        $globalCounter++
    }
}

function Clone-Files
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$ConfigFile,
        [Parameter(Mandatory=$true, Position=1)]
        [string]$SourceSettingEnvironment,
        [Parameter(Mandatory=$true, Position=2)]
        [string]$TargetSettingEnvironment
    )
    Write-Region -Text "Starting File cloning process" -Level 0
    Write-Formatted -Message "Source Setting Environment: $SourceSettingEnvironment" -Mode INFO -Level 1
    Write-Formatted -Message "Target Setting Environment: $TargetSettingEnvironment" -Mode INFO -Level 1
    $settingssFile = (Get-Content $ConfigFile) -join "`n" | ConvertFrom-Json
    $files = $settingssFile.settings.files
    $filesCount = $files.Count
    $baseDirectory = $pwd
    Write-Formatted -Message "Starting File cloning process with total of $filesCount files" -Mode INFO -Level 1
    Write-Host
    $globalCounter = 1
    foreach($file in $files)
    {
        $sourceFile = $file.file
        Write-Region -Text "$globalCounter/$filesCount - File `'$sourceFile`'" -Level 1
        Write-Formatted "Updating file `'$sourceFile`' name with .#ENVIRONMENT#. flags" -Mode INFO -Level 1
        Write-Formatted ".#ENVIRONMENT#. flags equals `".$SourceSettingEnvironment.`"" -Mode INFO -Level 1
        $sourceFile = [Regex]::Replace($sourceFile,[regex]::Escape(".#ENVIRONMENT#."),".$SourceSettingEnvironment.",[System.Text.RegularExpressions.RegexOptions]::IgnoreCase);
        $sourceFileFullPath = "$baseDirectory/$sourceFile" 
        Write-Formatted "Updating `"$sourceFileFullPath`"" -Mode INFO -Level 1
        Write-Formatted "Checking whether Source file `"$sourceFileFullPath`" exists" -Mode INFO -Level 1
        $fileExists = [System.IO.File]::Exists($sourceFileFullPath)
        if ($fileExists -eq $True)
        {
            $sourceFileFullPath = Resolve-Path $sourceFileFullPath
            Write-Formatted "Source file `"$sourceFileFullPath`" already exists" -Mode INFO -Level 1
            $destinationFullFileName = [Regex]::Replace($sourceFileFullPath,[regex]::Escape(".$SourceSettingEnvironment."),".$TargetSettingEnvironment.",[System.Text.RegularExpressions.RegexOptions]::IgnoreCase);
            Write-Formatted "Checking if destination file `"$destinationFullFileName`" exists" -Mode INFO -Level 1
            $destinationFileExists = [System.IO.File]::Exists($destinationFullFileName)
            if ($destinationFileExists -eq $true)
            {
                $sourceFileContent = Get-Content $sourceFileFullPath
                $destinationBackupFileName = Get-BackupFileName $destinationFullFileName
                Write-Formatted "Destination file `"$destinationFullFileName`" exists" -Mode INFO -Level 1
                Write-Formatted "Creating a backup `"$destinationBackupFileName`" before overriding" -Mode INFO -Level 1
                $destinationFullFileNameContent = Get-Content $destinationFullFileName
                $destinationFullFileNameContent > $destinationBackupFileName
            }
            else
            {
                Write-Formatted "Destination file `"$destinationFullFileName`" does not exist; no backup needed." -Mode INFO -Level 1
            }
            Write-Formatted "Saving source file to target file `"$destinationFullFileName`"" -Mode INFO -Level 1
            $sourceFileContent > $destinationFullFileName
        }
        else
        {
            Write-Formatted -Message "Target file `"$sourceFileFullPath`" does not exist" -Mode "ERROR" -Level 1
        }
        Write-EndingLine -Level 1
        Write-Host
        $globalCounter++
    }
}

function PrependTo-File{
    [cmdletbinding()]
    param(
      [Parameter(
        Position=1,
        ValueFromPipeline=$true,
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true
      )]
      [System.IO.FileInfo]
      $file,
      [string]
      [Parameter(
        Position=0,
        ValueFromPipeline=$false,
        Mandatory=$true
      )]
      $content
    )
  
    process{
      if(!$file.exists){
        write-error "$file does not exist";
        return;
      }
      $filepath = $file.fullname;
      $tmptoken = (get-location).path + "\_tmpfile" + $file.name;
      write-verbose "$tmptoken created to as buffer";
      $tfs = [System.io.file]::create($tmptoken);
      $fs = [System.IO.File]::Open($file.fullname,[System.IO.FileMode]::Open,[System.IO.FileAccess]::ReadWrite);
      try{
        $msg = $content.tochararray();
        $tfs.write($msg,0,$msg.length);
        $fs.position = 0;
        $fs.copyTo($tfs);
      }
      catch{
        write-verbose $_.Exception.Message;
      }
      finally{
  
        $tfs.close();
        # close calls dispose and gc.supressfinalize internally
        $fs.close();
        if($error.count -eq 0){
          write-verbose ("updating $filepath");
          [System.io.File]::Delete($filepath);
          [System.io.file]::Move($tmptoken,$filepath);
        }
        else{
          $error.clear();
          write-verbose ("an error occured, rolling back. $filepath not effected");
          [System.io.file]::Delete($tmptoken);
        }
      }
    }
  }
  
function Clone-Repositories
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$configFileName,
        [Parameter(Mandatory=$false, Position=1)]
        [bool]$useHttp
    )
    Write-Region -Text "Cloning from Config file `"$configFileName`"" -Level 0 -ForegroundColor Green
    $repositoriesConfigFile = [IO.Path]::GetFullPath("$pwd\$configFileName")
    $repositoriesConfigFileExists = Test-Path -Path $repositoriesConfigFile
    if ($repositoriesConfigFileExists -eq $true)
    {
        $repositoriesFile = (Get-Content $repositoriesConfigFile) -join "`n" | ConvertFrom-Json
        $repositories = $repositoriesFile.repositories
        $repositoriesCount = $repositories.Count
        $baseDirectoryPath = $repositoriesFile.baseDirectoryPath
        Write-Formatted -Message "Base Directory Path => $baseDirectoryPath" -Mode INFO -Level 0
        $baseDirectory = [IO.Path]::GetFullPath("$pwd\$baseDirectoryPath")
        $baseDirectoryExists = Test-Path -Path $baseDirectory -PathType Container
        if ($baseDirectoryExists -eq $false)
        {
            Write-Formatted -Message "Directory `'$baseDirectory`' does not exist! Attempting to create ...."
            New-Item -Path $baseDirectory -ItemType Directory
            $baseDirectoryExists = Test-Path -Path $baseDirectory -PathType Container
            if ($baseDirectoryExists -eq $true)
            {
                Write-Formatted -Message "Directory `'$baseDirectory`' created!"
            }
            else
            {
                Write-Formatted -Message "Fatal Error! Failed to create directory!" -Mode ERROR -Level 0
            }

        }
        else
        {
            Write-Formatted -Message "Directory `'$baseDirectory`' exists"
        }
        Write-Formatted -Message "Cloning $repositoriesCount Repositories"
        Write-Host
        $counter = 1
        If ($useHttp -eq $True)
        {
            Write-Formatted -Message "Using Git HTTP mode"
        }
        else
        {
            Write-Formatted -Message "Using Git SSH mode"
        }
        Write-Host
        foreach($repository in $repositories)
        {
            Set-Location $baseDirectory
            $repositoryName = $repository.name
            $repositoryHttpUrl = $repository.http_url
            $repositorySshUrl = $repository.ssh_url
            $repositoryUrl = $repositorySshUrl
            If ($useHttp -eq $True)
            {
                $repositoryUrl = $repositoryHttpUrl
            }
            $barnchName = $repository.branch
            Write-Region -Text "$counter/$repositoriesCount - Checking Repository `"$repositoryName`"" -Level 1
            $directoryName = "$baseDirectory\$repositoryName"
            # if directory already exists, means it has already been cloned
            Write-Formatted -Message "Checking whether directory `"$directoryName`" already exists" -Mode INFO -Level 1
            $directoryExists = Test-Path -Path $directoryName -PathType Container
            if ($directoryExists -eq $True)
            {
                Set-Location -Path $directoryName
                Write-Formatted -Message "Branch `"$barnchName`" for Repository `"$repositoryName`" already exists" -Mode INFO -Level 1
			    Write-Formatted -Message "Checking out the `"$barnchName`" branch of Repository `"$repositoryName`" at `"$directoryName`"" -Mode INFO -Level 1
			    $gitCheckoutCommandText = "git checkout -b $barnchName"
			    $gitCheckoutCommand = git checkout $barnchName -q
			    Write-Formatted -Message "Command to execute: $gitCheckoutCommandText" -Mode INFO -Level 1
			    $gitCheckoutCommand
			    Write-Formatted -Message "Checkout finished" -Mode INFO -Level 1
			    Write-Formatted -Message "Pulling the `"$barnchName`" branch of remote Repository `"$repositoryName`" at `"$directoryName`"" -Mode INFO -Level 1			
                $gitPullCommandText = "git pull origin $barnchName"
                $gitPullCommand = git pull -q
                Write-Formatted -Message "Attempting to pull with command: $gitPullCommandText" -Mode INFO -Level 1
                $gitPullCommand
                Write-Formatted -Message "Pull finished" -Mode INFO -Level 1
            }
            else
            {
                ## Cloning Repository
                Write-Formatted -Message "Branch `"$barnchName`" for Repository `"$repositoryName`" does not exist ... Attempting to clone" -Mode INFO -Level 1
                $gitCloneCommandText = "git clone $repositoryUrl"
                $gitCloneCommand = git clone $repositoryUrl -q
                Write-Formatted -Message "Command to execute: $gitCloneCommandText" -Mode INFO -Level 1
                Write-Formatted -Message "Cloning Repository `"$repositoryName`"" -Mode INFO -Level 1
                $gitCloneCommand
                Write-Formatted -Message "Clone finished" -Mode INFO -Level 1
                $directoryExists = Test-Path -Path $directoryName -PathType Container
                if ($directoryExists -eq $True)
                {
                    Set-Location -Path $directoryName
                    Write-Formatted -Message "Checking out the `"$barnchName`" branch of Repository `"$repositoryName`" at `"$directoryName`"" -Mode INFO -Level 1
                    $gitCheckoutCommandText = "git checkout -b $barnchName"
                    $gitCheckoutCommand = git checkout $barnchName -q
                    Write-Formatted -Message "Command to execute: $gitCheckoutCommandText" -Mode INFO -Level 1
                    $gitCheckoutCommand
                    Write-Formatted -Message "Checkout finished" -Mode INFO -Level 1
				    Write-Formatted -Message "Pulling the `"$barnchName`" branch of remote Repository `"$repositoryName`" at `"$directoryName`"" -Mode INFO -Level 1				
                    $gitPullCommandText = "git pull origin $barnchName"
                    $gitPullCommand = git pull -q
                    Write-Formatted -Message "Attempting to pull with command: $gitPullCommandText" -Mode INFO -Level 1
                    $gitPullCommand
                    Write-Formatted -Message "Pull finished" -Mode INFO -Level 1
                }
                else
                {
                    Write-Error "There was an error cloning the repository `"$repositoryName`"" -ForegroundColor red
                }        
            }
            Set-Location -Path $baseDirectory
            $counter++
            Write-Line -TextCount 100 -Level 1
            Write-Host
        }
        Set-Location $baseDirectory
    }
    else
    {
        Write-Formatted -Message "Unable to open configurations file `'$repositoriesConfigFile`'" -Mode ERROR -Level 0
    }
}

function Build-DockerImages
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false, Position=0)]
        [bool]$incrementVersion
    )
    #####

    Clear-Host
    $directoriesNames = Get-Content "directories.txt"
    $directoriesCount = $directoriesNames.Count
    $rootDirectory = $pwd
    $dockerRepoPrefix = "nexus.elm.sa/aabuabdou/inspection"
    Write-Host "Enumerating $directoriesCount directories" -ForegroundColor White
    Write-Host
    $counter = 1
    foreach($directoryName in $directoriesNames)
    {
        $currentDirectoryFullPath = "$rootDirectory\$directoryName"
        Write-Host "$counter/$directoriesCount Processing directory $currentDirectoryFullPath" -ForegroundColor Green
        Set-Location $currentDirectoryFullPath
        $fileVersionFullPath = "$currentDirectoryFullPath\docker-version.txt"        
        $currentVersionFileExists = [System.IO.File]::Exists($fileVersionFullPath)
        if ($currentVersionFileExists -eq $True)
        {
            $currentVersion = Get-Content "docker-version.txt"
            $dockerFileNameFullPath = "$currentDirectoryFullPath\docker-name.txt"
            $dockerFileNameExists = [System.IO.File]::Exists($dockerFileNameFullPath)
            if ($dockerFileNameExists -eq $True)
            {
                $dockerImageName = Get-Content "docker-name.txt"
                $dockerRepo = "$dockerRepoPrefix"
                $dockerRepo += "/$dockerImageName"
                $dockerRepo += ":$currentVersion"
                #$dockerImageDeleteCommand = "docker rmi $dockerRepo"
                #Write-Host "Running docker image delete command => `"$dockerImageDeleteCommand`"" -ForegroundColor White
                #iex $dockerImageDeleteCommand
                $dockerBuildCommand = "docker build -t $dockerRepo ."
                Write-Host "Running docker build command => `"$dockerBuildCommand`"" -ForegroundColor White
                iex $dockerBuildCommand
                $dockerPushCommand = "docker push $dockerRepo"
                Write-Host "Running docker push command => `"$dockerPushCommand`"" -ForegroundColor White
                iex $dockerPushCommand
                If ($incrementVersion -eq $True)
                {
                    Write-Host "Versioning auto-increment is enabled"
                    $newerVersion = [int]$currentVersion
                    $newerVersion++
                    Set-Content -Path "docker-version.txt" -Value $newerVersion
                }
                else
                {
                    Write-Host "Versioning auto-increment is disabled"
                }
            }
            else
            {
                Write-Host "File `"$dockerFileNameFullPath`" does not exist" -ForegroundColor Red
            }
        }
        else
        {
            Write-Host "File `"$fileVersionFullPath`" does not exist" -ForegroundColor Red
        }
        Set-Location $rootDirectory

        $counter++
        Write-Host "----------------------------------------------------------------"
        Write-Host
    }

    #####
}

function Build-Angular
{
    Clear-Host
    $directoriesNames = Get-Content "angular-folders-new.txt"
    $directoriesCount = $directoriesNames.Count
    $rootDirectory = $pwd
    Write-Host "Enumerating $directoriesCount directories" -ForegroundColor White
    Write-Host
    $counter = 1
    foreach($directoryName in $directoriesNames)
    {
        $currentDirectoryFullPath = "$rootDirectory\$directoryName"
        Write-Host "$counter/$directoriesCount Processing directory $currentDirectoryFullPath" -ForegroundColor Green
        $currentVersionFileExists = Test-Path $currentDirectoryFullPath -PathType Container
        if ($currentVersionFileExists -eq $True)
        {		
            Set-Location $currentDirectoryFullPath
            Write-Host "Removing existing node modules"			
			Remove-Item -Path .\node_modules\ -Confirm:$false -Recurse
            Write-Host "Removing existing Angular production build"			
			Remove-Item -Path .\dist\ -Confirm:$false -Recurse			
            Write-Host "Uninstalling previously installed version of Angular CLI"				
			npm uninstall --save-dev angular-cli
            Write-Host "Updating Angular CLI local version"
            & npm install --save-dev @angular/cli@latest
            Write-Host "Running `"npm install`" ..."
            & npm install
            Write-Host "Running `"ng build --prod`" ..."
            & ng build --prod
        }
        else
        {
            Write-Host "`"$currentDirectoryFullPath`" does not exist" -ForegroundColor Red
        }
        Set-Location $rootDirectory

        $counter++
        Write-Host "----------------------------------------------------------------"
        Write-Host
    }
}

function Write-Formatted 
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Message,
        [Parameter(Mandatory=$false, Position=1)]
        [ValidateSet('INFO', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Mode = "INFO",
        [Parameter(Mandatory=$false, Position=2)]
        [int]$Level = 0
    )
    $tabs = Get-Tabs -Level $Level
    $_mode = $mode.ToUpper()
    $msg = "[$_mode]`t$Message"
    if ($_mode -eq "ERROR")
    {
        Write-Host "$tabs$msg" -ForegroundColor Red
    }
    else
    {
        if ($_mode -eq "SUCCESS")
        {
            Write-Host "$tabs$msg" -ForegroundColor Green
        }
        else
        {
            if ($_mode -eq "DEBUG")
            {
                Write-Host "$tabs$msg" -ForegroundColor Yellow
            }
            else # INFO
            {
                Write-Host "$tabs$msg" -ForegroundColor White
            }
        }
    }
}

#
# Author: Prateek Singh
#
function Retry-Command {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true)]    [scriptblock]$ScriptBlock,
        [Parameter(Position=1, Mandatory=$false)]   [int]$Maximum = 10,
        [Parameter(Position=2, Mandatory=$false)]   [int]$Delay = 10
    )

    Begin {
        $count = 0
    }

    Process {
        do {
            $count++
            try {
                Write-Formatted "Retry: $($count)" -Level 1 -Mode INFO
                $ScriptBlock.Invoke()
                return
            } catch {
                # Write-Error $_.Exception.InnerException.Message -ErrorAction Continue
                Write-Formatted $_.Exception.InnerException.Message -Level 0 -Mode DEBUG -ErrorAction Continue
                Start-Sleep -Seconds $Delay
            }
        } while ($count -lt $Maximum)

        # Throw an error after $Maximum unsuccessful invocations. Doesn't need
        # a condition, since the function returns upon successful invocation.
        throw 'Execution failed.'
    }
}

function Write-EndingLine
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false, Position=1)]
        [int]$Level = 0
    )
    $line = Get-Tabs -Level $Level
    for ($i = 0; $i -lt 100; $i++)
    {
        $line += "-"
    }
    Write-Host $line
    Write-Host
}

function Write-Line
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false, Position=0)]
        [int] $TextCount = 100,
        [Parameter(Mandatory=$false, Position=1)]
        [int]$Level = 0,
        [Parameter(Mandatory=$false, Position=2)]
        [ValidateSet('White', 'Green')]
        [string]$ForegroundColor = "White"
    )    
    $line = Get-Tabs -Level $Level
    for ($i = 0; $i -lt $TextCount+4; $i++)
    {
        $line += "-"
    }
    if ($ForegroundColor -eq "Green")
    {
        Write-Host $line -ForegroundColor Green
    }
    else 
    {
        Write-Host $line        
    }
}

function Get-Tabs
{
    Param
    (
        [Parameter(Mandatory=$false, Position=1)]
        [int]$Level = 0
    )
    $tabs = ""
    $counter = 0;
    while ($counter -lt $Level)
    {
        $tabs += "`t"
        $counter++
    }
    return $tabs;
}

function Write-Region
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Text,
        [Parameter(Mandatory=$false, Position=1)]
        [int]$Level = 0,
        [Parameter(Mandatory=$false, Position=2)]
        [ValidateSet('White', 'Green')]
        [string]$ForegroundColor = "White"
    ) 
    $tabs = Get-Tabs -Level $Level       
    Write-Host
    if ($ForegroundColor -eq "Green")
    {
        Write-Line -TextCount $Text.Length -Level $Level -ForegroundColor Green
        Write-Host "$tabs| $Text |" -NoNewline -ForegroundColor Green
    }
    else 
    {
        Write-Line -TextCount $Text.Length -Level $Level
        Write-Host "$tabs| $Text |" -NoNewline        
    }
    Write-Host
    if ($ForegroundColor -eq "Blue")
    {
        Write-Line -TextCount $Text.Length -Level $Level -ForegroundColor Blue
    }
    else 
    {
        Write-Line -TextCount $Text.Length -Level $Level       
    }
    Write-Host
}

function Write-Heading
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Message,
        [Parameter(Mandatory=$false, Position=1)]
        [int]$Level = 0
    )
    $tabs = Get-Tabs -Level $Level
    $line = $tabs
    for ($i = 0; $i -lt 100; $i++)
    {
        $line += "-"
    }
    Write-Host $line
    Write-Host "$tabs$Message"
    Write-Host $line
    Write-Host
}

function Get-BackupFileName
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$FileName
    )

    $date = get-date
    $dateString = $date.ToString("dd-MM-yyyy--HHmmssfff")
    $backupFileName = "$FileName.$dateString.bak"
    return $backupFileName
}

function Get-FormattedDateAsString
{
	$date = get-date
    $dateString = $date.ToString("dd-MM-yyyy--HHmmss-fff")
    return $dateString
}

function Get-FormattedDateForDebugging
{
	$date = get-date
    $dateString = $date.ToString("dd-MM-yyyy--HH:mm:ss:fff")
    return $dateString
}

function Create-WebSite
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$ConfigFile
    )
    Import-Module WebAdministration
    $settingssFile = (Get-Content $ConfigFile) -join "`n" | ConvertFrom-Json
    Write-Region -Text "1. Creating main web site" -Level 0 -ForegroundColor Green
    $deployToIis = $settingssFile.site.deploy_to_iis
    $solutionsRoot = $settingssFile.site.solutions_root
    $userName = $settingssFile.site.iis_application_pool_identity
    $password = $settingssFile.site.iis_application_pool_password
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $defaultAppPool = $settingssFile.site.to_be_stopped_application_pool
    $DefaultSiteName = $settingssFile.site.to_be_stopped_website_name
    $iisPort = $settingssFile.site.iis_port
    $PhysicalPath = $settingssFile.site.iis_sites_physical_path
    $NewIisSiteName = $settingssFile.site.new_website_name
    $AppPoolName = $settingssFile.site.iis_application_pool_name 
    $updateAppPoolIdentityIfExists = $settingssFile.site.update_app_pool_identity_if_exists
    $webApplications = $settingssFile.site.web_applications
    $globalCommands = $settingssFile.site.global_commands
    $pfxPassword = $settingssFile.site.pfx_password
    $appPoolIdentity = $settingssFile.site.iis_application_pool_identity
    Write-Formatted -Message "Checking whether IIS deployment is enabled" -Mode INFO -Level 0
    if ($deployToIis -eq $true)
    {
        Write-Formatted -Message "Attempting to start the Windows Process Activation Service in case it is stopped" -Mode INFO -Level 0
        Get-Service WAS | ? { $_.Status -ne "Running" } | Start-Service
        Write-Formatted -Message "Attempting to start the World Wide Web Publishing Service in case it is stopped" -Mode INFO -Level 0
        Get-Service W3SVC | ? { $_.Status -ne "Running" } | Start-Service

        Write-Formatted -Message "IIS deployment is enabled" -Mode INFO -Level 0
        Write-Formatted -Message "Checking the state of default IIS web site `"$DefaultSiteName`"" -Mode INFO -Level 0
        $DefaultWebSiteState = Get-WebsiteState -Name $DefaultSiteName
        if ($DefaultWebSiteState.Value -ne "Stopped")
        {
            Write-Formatted -Message "Default Web Site is not stopped; Attempting to stop the default IIS web site" -Mode INFO -Level 0
            Stop-Website -Name $DefaultSiteName
            Get-ChildItem -Path "IIS:\AppPools" | ? {$_.Name -eq $DefaultAppPool -and $_.State -eq "Started"} | Stop-WebAppPool
            Write-Formatted -Message "Default IIS web site `"$DefaultSiteName`" stopped" -Mode INFO -Level 0
        }
        else
        {
            Write-Formatted -Message "Default Web Site is already stopped; no action needed" -Mode INFO -Level 0
        }
        Write-Formatted -Message "Checking whether web application pool `"$AppPoolName`" already exists" -Mode INFO -Level 0
        $appPool = Get-ChildItem -Path "IIS:\AppPools" | ? {$_.Name -eq $AppPoolName}
        $appPoolExists = $null -ne $appPool
        if ($appPoolExists)
        {
            Write-Formatted -Message "Web application pool `"$AppPoolName`" already exists; no action needed" -Mode INFO -Level 0
            if ($updateAppPoolIdentityIfExists -eq $true)
            {                
                Set-ItemProperty IIS:\AppPools\$AppPoolName -name processModel -value @{userName=$userName;password=$securePassword;identitytype=3}
                Write-Formatted -Message "Updated IIS Application Pool Identity with `"$userName`" credentials" -Mode INFO -Level 0
            }
        }
        else 
        {
            Write-Formatted -Message "Web application pool `"$AppPoolName`" does not exist! Creating a new web application pool `"$AppPoolName`"" -Mode INFO -Level 0
            New-WebAppPool -Name $AppPoolName
            Set-ItemProperty IIS:\AppPools\$AppPoolName -name processModel -value @{userName=$userName;password=$securePassword;identitytype=3}
            Write-Formatted -Message "Updated IIS Application Pool Identity with `"$userName`" credentials" -Mode INFO -Level 0
        } 
        Write-Formatted -Message "Checking if Web site with name `"$NewIisSiteName`" already exists" -Mode INFO -Level 0
        if (Get-ChildItem -Path "IIS:\Sites" | ? {$_.Name -eq $NewIisSiteName })
        {
            Write-Formatted -Message "Web site with name `"$NewIisSiteName`" already exists; no action needed" -Mode INFO -Level 0
        }
        else
        {
            Write-Formatted -Message "Web site with name `"$NewIisSiteName`" does not exist. Attempting to create web site" -Mode INFO -Level 0
            Write-Formatted -Message "Creating a new web site with name `"$NewIisSiteName`"" -Mode INFO -Level 0
            Write-Formatted -Message "Checking whether IIS physical path exists `"$PhysicalPath`"" -Mode INFO -Level 0
            $destinationExists = Test-Path $PhysicalPath -PathType Container
            If ($destinationExists -eq $false)
            {
                Write-Formatted -Message "Destination `"$PhysicalPath`" does not exist. Attempting to create ..."
                New-Item $PhysicalPath -ItemType Container
                Write-Formatted -Message "Destination `"$PhysicalPath`" created"
            }
            else 
            {
                Write-Formatted -Message "Destination `"$PhysicalPath`" already exists; no action needed"
            }
            New-Website -Name $NewIisSiteName -PhysicalPath (Resolve-Path $PhysicalPath) -Port $iisPort -ApplicationPool $AppPoolName
        }
    }
    else 
    {
        Write-Formatted -Message "IIS deployment is disabled" -Mode INFO -Level 0
    }    

    Write-Region -Text "2. Creating web applications as e-services" -Level 0 -ForegroundColor Green
    $webApplicationsCount = $webApplications.Count
    Write-Formatted "Creating $webApplicationsCount web applications" 
    $webApplicationsCounter = 1
    $scriptsLocation = Get-Location
    $solutionsRootFolder = Resolve-Path $solutionsRoot
    foreach($webApplication in $webApplications)
    {
        $deploy = $webApplication.deploy
        $websiteName = $webApplication.website_name
        if ($deploy -eq $true)
        {
            Write-Formatted -Message "Deployment is enabled for $websiteName. Proceeding with deployment ..." -Mode INFO -Level 1
            $solutionFolder = $webApplication.solution_folder_name
            $webApplicationFolder = Resolve-Path "$solutionsRootFolder/$solutionFolder"
            $solutionFolderExists = Test-Path -Path $webApplicationFolder -PathType Container
            Write-Formatted -Message "Checking whether the solution folder `"$webApplicationFolder`" exists" -Mode INFO -Level 1
            if ($solutionFolderExists -eq $true)
            {
                Set-Location $webApplicationFolder
                Write-Formatted -Message "Solution folder `"$webApplicationFolder`" exists; No action needed" -Mode INFO -Level 1
                $webAppName = $webApplication.website_name
                Write-Region -Text "$webApplicationsCounter/$webApplicationsCount `"$webAppName`" service" -Level 1 -ForegroundColor Green
                If ($webApplication.skip_global_commands -eq $true)
                {
                    Write-Formatted "Global Commands will be skipped" -Mode INFO -Level 1
                    $localCommands = $webApplication.local_commands
                    $localCommandsExist = $null -ne $localCommands
                    Write-Formatted "Local Commands mode is selected; checking for local commands existence ..." -Mode INFO -Level 1
                    if ($localCommandsExist -eq $true)
                    {
                        Write-Formatted "Local Commands will be applied" -Mode INFO -Level 1
                        $localCommandsCount = $localCommands.Count
                        Write-Formatted "$localCommandsCount Global Commands will be applied" -Mode INFO -Level 1
                        foreach($localCommand in $localCommands)
                        {
                            $command = $localCommand.command
                            $webSiteName = $webApplication.website_name
                            $pascalName = $webApplication.pascal_name
                            $command = $command -replace "{website_name}", $webSiteName
                            $command = $command -replace "{pascal_name}", $pascalName
                            $command = $command -replace "{pfx_password}", $pfxPassword
                            $command = $command -replace "{iis_application_pool_identity}", $appPoolIdentity
                            $command = $command -replace "{script_path}", $scriptsLocation
                            Write-Formatted "Executing command `"$command`"" -Level 2
                            Invoke-Expression $command
                        }
                    }
                    else 
                    {
                        Write-Formatted "Local Commands do not exist!" -Mode ERROR -Level 1
                    }
                }
                else
                {
                    Write-Formatted "Global Commands mode is selected; checking for global commands existence ..." -Mode INFO -Level 1
                    $globalCommandsExist = $null -ne $globalCommands
                    if ($globalCommandsExist -eq $true)
                    {
                        $globalCommandsCount = $globalCommands.Count
                        Write-Formatted "$globalCommandsCount Global Commands will be applied" -Mode INFO -Level 1
                        foreach($globalCommand in $globalCommands)
                        {
                            $command = $globalCommand.command
                            $webSiteName = $webApplication.website_name
                            $pascalName = $webApplication.pascal_name
                            $command = $command -replace "{website_name}", $webSiteName
                            $command = $command -replace "{pascal_name}", $pascalName
                            $command = $command -replace "{pfx_password}", $pfxPassword
                            $command = $command -replace "{iis_application_pool_identity}", $appPoolIdentity
                            $command = $command -replace "{script_path}", $scriptsLocation
                            Write-Formatted "Executing command `"$command`"" -Level 2
                            Invoke-Expression $command
                        }
                    }
                    else 
                    {
                        Write-Formatted "Global Commands do not exist!" -Mode ERROR -Level 1
                    }
                }
            }
            else 
            {
                Write-Formatted -Message "Solution folder `"$webApplicationFolder`" does not exist! Aborting" -Mode ERROR -Level 1
            }
        }
        else 
        {
            Write-Formatted -Message "Deployment is disabled for $websiteName. Skipping deployment ..." -Mode INFO -Level 1
        }
        $webApplicationsCounter++
        Set-Location $scriptsLocation
    }
}

# Author: Michael Armitage
# Url: https://stackoverflow.com/questions/40046916/how-to-grant-permission-to-user-on-certificate-private-key-using-powershell
# Modified by: Ahmed Khalil Abuabdou

function Set-CertificatePrivateKeyPermission
{
    [CmdletBinding()]
    param (
        [string]$certStorePath  = "Cert:\LocalMachine\My",
        #[string]$AppPoolName,
        [string]$userName,
        [string]$certThumbprint
        )

    Import-Module WebAdministration

    $certificate = Get-ChildItem $certStorePath | Where-Object thumbprint -eq $certThumbprint

    $rsaCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
    $fileName = $rsaCert.key.UniqueName
    $path = "$env:ALLUSERSPROFILE\Microsoft\Crypto\Keys\$fileName"
    $permissions = Get-Acl -Path $path

    #$iis_access_rule = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS AppPool\$AppPoolName", 'FullControl', 'None', 'None', 'Allow')
    $user_access_rule = New-Object System.Security.AccessControl.FileSystemAccessRule($userName, 'FullControl', 'None', 'None', 'Allow')
    #$permissions.AddAccessRule($iis_access_rule)
    $permissions.AddAccessRule($user_access_rule)
    Set-Acl -Path $path -AclObject $permissions
}

function Stop-Windows-Service {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ServiceName
    )

    Write-Heading "Stopping Windows service: [$($ServiceName)]"

    $service = Get-Service $ServiceName -ErrorAction SilentlyContinue
    if ($service) {

        if ($service.Status -eq "Running") {
            Stop-Service -Name $ServiceName -Force -ErrorAction Stop
            Write-Formatted "Windows service [$($ServiceName)] has been stopped" -Level 0 -Mode SUCCESS
        }
        else {
            Write-Formatted "Windows service [$($ServiceName)] is not running. Status: [$($service.Status)]" -Level 0 -Mode DEBUG
        }
    }
    Else {
        Write-Formatted "Windows service [$($ServiceName)] does not exist" -Level 0 -Mode DEBUG
    }
}

function Remove-Windows-Service {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ServiceName
    )

    Write-Heading "Removing Windows service: [$($ServiceName)]"

    $service = Get-Service $ServiceName -ErrorAction SilentlyContinue
    if ($service) {

        if ($service.Status -eq "Running") {
            Stop-Windows-Service -ServiceName $ServiceName
        }
        Remove-Service -Name $ServiceName -ErrorAction Stop
        Write-Formatted "Windows service [$($ServiceName)] has been Removed" -Level 0 -Mode SUCCESS
    }
    Else {
        Write-Formatted "Windows service [$($ServiceName)] does not exist" -Level 0 -Mode DEBUG
    }
}

function Stop-and-Delete-Service {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ServiceName
    )

    Stop-Windows-Service -ServiceName $ServiceName
    Remove-Windows-Service -ServiceName $ServiceName
    
}
function Delete-Dir-Or-File {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    Write-Heading "Removing item: [$($Path)]"

    if (Test-Path $Path) {
        Remove-Item $Path -Force -Confirm:$false -Recurse
        Write-Formatted "Item: [$($Path)] has been Removed" -Level 0 -Mode SUCCESS
    }
    else {
        Write-Formatted "Item: [$($Path)] does not exist" -Level 0 -Mode DEBUG
    }
}

function Start-Windows-Service {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ServiceName
    )

    Write-Heading "Starting Windows service: [$($ServiceName)]"

    $service = Get-Service $ServiceName -ErrorAction SilentlyContinue
    if ($service) {

        if ($service.Status -eq "Running") {
            Write-Formatted "Windows service [$($ServiceName)] alredy running" -Level 0 -Mode DEBUG

            
        }
        else {
            Start-Service -Name $ServiceName  -ErrorAction Stop
            Write-Formatted "Windows service [$($ServiceName)] has been Started" -Level 0 -Mode SUCCESS
        }
    }
    Else {
        Write-Formatted "Windows service [$($ServiceName)] does not exist" -Level 0 -Mode DEBUG
    }
}