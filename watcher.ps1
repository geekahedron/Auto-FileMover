# watcher.ps1
# Created: 2018-12-04
# Author: geekahedron
# Purpose: Watch for new/changed files export folder and copy them to designated directory
$version = "0.1"

# Specify folder locations
$fileshare = "\\fileserver\share\"
$scriptPath = "C:\scripts\watcher"

# Define "drives" to use to access files
New-PSDrive -Name "Share" -PSProvider FileSystem -Root $fileshare
New-PSDrive -Name "Watcher" -PSProvider FileSystem -Root $scriptPath

# Source and destination directories for each type
$sourceFolder = "Share:\export"
$destFolder = "Share:\backup"
$watchLog = "Watcher:\watcherlog.txt"

# Define watcher objects and register actions for triggered events
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = (Get-Item $currencySource).FullName
$watcher.Filter = "*.*"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true  

$createAction = {
	$path = $Event.SourceEventArgs.FullPath
	$changeType = $Event.SourceEventArgs.ChangeType
	$logline = "$(Get-Date) | $changeType, $path, $((Get-Item $path).length)"
	Add-content $watchLog -value $logline
	Start-Job -ScriptBlock $movefunction -argumentList @($path, (Get-Item $destFolder).FullName, (Get-Item $watchLog).FullName)
}

$watcherAction = {
	$path = $Event.SourceEventArgs.FullPath
	$changeType = $Event.SourceEventArgs.ChangeType
	$logline = "$(Get-Date) | $changeType, $path, $((Get-Item $path).length)"
	Add-content $watchLog -value $logline
}

Register-ObjectEvent $watcher "Created" -Action $createAction
Register-ObjectEvent $watcher "Changed" -Action $watcherAction
Register-ObjectEvent $watcher "Deleted" -Action $watcherAction
Register-ObjectEvent $currencywatcher "Renamed" -Action $watcherAction

# Code block "function" to watch a newly created file until it's done writing changes
$movefunction  = {
    param (
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$path,
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$destination,
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$logfile = "C:\watcher\defaultlog.txt"
    )
    Write-Output $path $destination $logfile
    Add-content $logfile -value "$(Get-Date) | Watching $($path) then moving to $($destination)"
	$secondsToWait = 3
	
    $filesize = 0
    $newfilesize = (Get-Item $path).length
    do {
        Add-Content $logfile -value "$(Get-Date) | $($path) changed ($($filesize):$($newfilesize)), waiting $($secondsToWait) seconds"
        $filesize = (Get-Item $path).length
        Start-Sleep -s $secondsToWait
    } while (($newfilesize = ((Get-Item $path).length)) -ne $filesize)
    Add-Content $logfile -value "$(Get-Date) | No change in file size ($($filesize):$($newfilesize))"
    Move-Item -path $path -destination $destination -Force
    Add-content $logfile -value "$(Get-Date) | Moved $($path) to $($destination)"
}

# Keep track of service restarts (and make sure everything runs to this point)
Add-content $watchLog -value "$(Get-Date) | Started running Watcher $($version)"
