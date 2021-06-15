#Requires -Version 5.0
# This script will inspect files from the provided source directory, and move them into a directory based on their LastWriteTime.
# https://github.com/deadlydog/MoveFilesIntoDateDirectories
# modified by beczel 2021-06-14 v.1.00

[CmdletBinding()]
Param
(
	[Parameter(Mandatory = $true, HelpMessage = 'The directory to look for files to move in.')]
	[ValidateNotNullOrEmpty()]
	[System.IO.DirectoryInfo] $SourceDirectoryPath,

	[Parameter(Mandatory = $true, HelpMessage = 'The directory to create the date-named directories in and move the files to.')]
	[ValidateNotNullOrEmpty()]
	[System.IO.DirectoryInfo] $TargetDirectoryPath,

	[Parameter(Mandatory = $false, HelpMessage = 'How many subdirectories deep the script should search for files to move. Default is no limit.')]
	[ValidateRange(0, [int]::MaxValue)]
	[int] $SourceDirectoryDepthToSearch = 0, #[int]::MaxValue,

	[Parameter(Mandatory = $false, HelpMessage = 'The scope at which directories should be created. Accepted values include "Hour", "Day", "Month", or "Year". e.g. If you specify "Day" files will be moved from the `SourceDirectoryPath` to `TargetDirectoryPath\yyyy-MM-dd`.')]
	[ValidateSet('Hour', 'Day', 'Month', 'Year')]
	[string] $TargetDirectoriesDateScope = 'Day',

	[Parameter(Mandatory = $false, HelpMessage = 'If provided, the script will overwrite existing files instead of reporting an error the the file already exists.')]
	[switch] $Force,

	[Parameter(Mandatory = $false, HelpMessage = 'Do you want to compress directories?')]
	[ValidateRange(0, 1)]
	[int] $TargetDirectoryPathCompressFolder = 1,

	[Parameter(Mandatory = $false, HelpMessage = 'How many days to search?')]
	[ValidateRange(-365, 365)]
	[int] $Daysback = -7,

	[Parameter(Mandatory = $false, HelpMessage = 'Prefix for directory')]
	[ValidateSet('Logs_', '')]
	[string] $TargetDirectoriesPrefix = 'Logs_'
)


Process
{

# Jesli katalogi są puste zakoncz
[int] $SourceDirectoryPathCount= (Get-ChildItem -LiteralPath $SourceDirectoryPath -File -Force -Recurse -Depth $SourceDirectoryDepthToSearch | where LastWriteTime -lt (Get-Date).AddDays($Daysback) | Measure-Object).Count

if( $SourceDirectoryPathCount -eq 0)
{
 echo "Folder is empty"
 exit
}

# Przenies pliki

	[System.Collections.ArrayList] $filesToMove = @(Get-ChildItem -LiteralPath $SourceDirectoryPath -File -Force -Recurse -Depth $SourceDirectoryDepthToSearch | where LastWriteTime -lt (Get-Date).AddDays($Daysback))

	$filesToMove | ForEach-Object {
		[System.IO.FileInfo] $file = $_
		[DateTime] $fileDate = $file.LastWriteTime
		[string] $dateDirectoryName = Get-FormattedDate -date $fileDate -dateScope $TargetDirectoriesDateScope
		[string] $dateDirectoryPath = Join-Path -Path $TargetDirectoryPath -ChildPath $TargetDirectoriesPrefix$dateDirectoryName
		Ensure-DirectoryExists -directoryPath $dateDirectoryPath
		[string] $filePath = $file.FullName
		[string] $fileName = $file.Name
	
		Write-Information "Moving file '$filePath' into directory '$dateDirectoryPath'."
		Move-Item -LiteralPath $filePath -Destination $dateDirectoryPath -Force:$Force

#		Write-Information "Compress file '$filePath' in zip $dateDirectoryPath.zip."
#		Compress-Archive -LiteralPath $dateDirectoryPath'\'$fileName -DestinationPath $dateDirectoryPath'.zip' -update

#		Write-Information "Delete file '$filePath' from directory '$dateDirectoryPath'."
#		Remove-Item -LiteralPath $dateDirectoryPath'\'$fileName -Force
	}


# Skompresuj katalogi i usun jak puste
if( $TargetDirectoryPathCompressFolder -eq 1)
{
	[System.Collections.ArrayList] $EmptyfolderToDel = @(Get-ChildItem -LiteralPath $TargetDirectoryPath -Directory -Force -Recurse -Depth 0)
	$EmptyfolderToDel | ForEach-Object {
		[System.IO.DirectoryInfo] $folderName = $_
		[string] $folderPath = $folderName.FullName

		if( (Get-ChildItem -LiteralPath $folderPath -Directory -Force -Recurse -Depth 0 | Measure-Object).Count -eq 0)
		{
		Write-Information "Compress file '$filePath' in zip $dateDirectoryPath.zip."
		Compress-Archive -LiteralPath $folderPath -DestinationPath $folderPath'.zip' -update
		}

		if( (Get-ChildItem -LiteralPath $folderPath -Directory -Force -Recurse -Depth 0 | Measure-Object).Count -eq 0)
		{
		echo "Delete empty folder : '$folderPath'"
		Remove-Item -LiteralPath $folderPath -Force -Recurse
		}
	}

}

}


Begin
{
	$InformationPreference = "Continue"
	$VerbosePreference = "Continue"

	function Get-FormattedDate([DateTime] $date, [string] $dateScope)
	{
		[string] $formattedDate = [string]::Empty
		switch ($dateScope)
		{
			'Hour' { $formattedDate = $date.ToString('yyyy-MM-dd-HH') }
			'Day' { $formattedDate = $date.ToString('yyyy-MM-dd') }
			'Month' { $formattedDate = $date.ToString('yyyy-MM') }
			'Year' { $formattedDate = $date.ToString('yyyy') }
			Default { throw "The specified date scope '$dateScope' is not valid. Please provide a valid scope." }
		}
		return $formattedDate
	}

	function Ensure-DirectoryExists([string] $directoryPath)
	{
		if (!(Test-Path -Path $directoryPath -PathType Container))
		{
			Write-Verbose "Creating directory '$directoryPath'."
			New-Item -Path $directoryPath -ItemType Directory -Force > $null
		}
	}

	# Display the time that this script started running.
	[datetime] $startTime = Get-Date
	Write-Verbose "Starting script at '$startTime'." -Verbose
}

End
{
	# Display the time that this script finished running, and how long it took to run.
	[datetime] $finishTime = Get-Date
	[timespan] $elapsedTime = $finishTime - $startTime
	Write-Verbose "Finished script at '$finishTime'. Took '$elapsedTime' to run." -Verbose
}
