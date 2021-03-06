cls

.'d:\Projects\LocalRepo\WhiteScope-Public\PS1\Get-FileSignatures.ps1'

#Execute a dir command and pipeline the results into the function, then take the results and export to csv
#Special note that currently using piped dir for the path info does not work correctly with calculating a file name excluding root path
dir 'C:\Windows\System32\drivers\etc' | Get-FileSignatures | Export-Csv 'c:\temp\drivers_etc.csv'

#Call function directly and export results to csv
Get-FileSignatures 'C:\Windows\System32\drivers' -IncludeVersionData $true | Export-Csv "c:\temp\file.csv"

#Call function directly, print verbose messages, and export results to a grid view displayed on the screen.  This directory will have many files with interesting version and signing data
Get-FileSignatures 'C:\Windows\System32\drivers' -IncludeVersionData $true -IncludeAuthenticodeData $true  | Out-GridView

#Same as previous but this time explicity include root path information
Get-FileSignatures 'C:\Windows\System32\drivers' -IncludeVersionData $true -IncludeAuthenticodeData $true -IncludeRootPath $true  | Out-GridView

# This example shows you can can add metadata to the list of signatures as well as output to JSON or XML
# The JSON output is of special interest as it can be used to support later functionality interacting with an API

#Create the object to hold the complex resultset
$Results = New-Object -TypeName PSObject

#Create MetaData to include with results.  This can be freeform with whatever data you wish to tag to the list of signatures
$MetaData = @{
	Product='Product1'
	Manufacturer='Hello Company'
    Version='3.1.4A'
	MediaSource='Web-Download'
	}

$Results | Add-Member $MetaData -Name "metadata" -MemberType NoteProperty

# Get the signatures
$Signatures = Get-FileSignatures 'C:\Windows\System32\drivers\etc' -IncludeVersionData $true -IncludeAuthenticodeData $true -IncludeRootPath $true 

#Add the signatures to the object
$Results | Add-Member -Value $Signatures -Name "signatures" -MemberType NoteProperty

# Write contents out to JSON.  Note that this function requires Powershell 3.0 minimum.
$Results | ConvertTo-Json -Compress | Out-File -FilePath $($(Split-Path -parent $MyInvocation.MyCommand.Definition) + '\output.json')

#Get help information for this function
Get-Help Get-FileSignatures -Detailed