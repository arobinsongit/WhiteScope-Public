#requires -Version 2.0

Function Verify-FileHashes
{
<#
.SYNOPSIS
Verify file hashes by comparing to a known reference.

.DESCRIPTION
This command will take the typical output of the Get-FileSignature cmdlet and compare it to a set of reference data.

Special Note: You must have at least read privileges on the files and folder specified.

.PARAMETER FileSignatures
Calculated signatures of target files

Aliases
fs

.PARAMETER ReferenceSignatures
Signatures against which you should compare calculated file signatures

Aliases
rs

.PARAMETER MissingHashText
Alternative text to use if there is no matching file in the reference data.

Default
N/A

Aliases
mht

.EXAMPLE
PS C:\> Get-FileSignatures 'C:\Windows\explorer.exe' -$Recurse:False | Verify-FileSignatures -ReferenceSignatures $(Import-Csv '.\reference.csv')

Compare the file signatures for explorer.exe to signature data stored in in a references.csv file.

.EXAMPLE
$SignatureData = Get-FileSignatures 'v:\downloads\gpg4win-2.3.2.exe' -Recurse:$false
$ReferenceData = $(Import-Csv '.\refdata.csv')
Verify-FileHashes -FileSignatures $SignatureData -ReferenceSignatures $ReferenceData | Out-GridView

Compare the file signatures for gpg4win-2.3.2.exe to signature data stored in in a references.csv file.

.EXAMPLE
Verify-FileHashes -GetEmptyReferenceData:$true | Export-Csv 'example-refdata.csv'

Get an empty CSV file to use for reference data.

.EXAMPLE
Verify-FileHashes -GetEmptyReferenceData:$true | Export-Csv 'example-refdata.csv'

Get an empty CSV file to use for reference data.

.EXAMPLE
$SignatureData = Get-FileSignatures 'V:\media\duosecurity' -Recurse:$false
$ReferenceData = $(Import-Csv '.\ref.csv')
Verify-FileHashes -FileSignatures $SignatureData -ReferenceSignatures $ReferenceData -MissingHashText "Missing"

SHA256Hash      : 845F9B4E666BDD5EB129910FE906CB34824DAFF37BF0174D3FCA741DC06CEDF5
MD5Hash         : 42CD3AF91AF1894D7C58CF5DD424CF72
SHA256HashMatch : Missing
SHA512Hash      : 473A87FDB04AF9092714AAA706A8F68CA1C270609119AB8B744B9E2B09D18FE6B751863FA92A3F6A7D572D0A63EF98FBB6F6617CD53AAF5841CC549A3EC28E49
SHA1Hash        : CD9FD2FF313485582598322B5CFFD228F37051B3
SHA1HashMatch   : Missing
FileFilename    : duoauthproxy-2.4.17-src.tgz
SHA512HashMatch : Missing
MD5HashMatch    : Missing

SHA256Hash      : 4B3B799B2D7BD21F18FC7776937DE6AF79B9AD2A075D5D1506D251A5CCD59732
MD5Hash         : 5892D6A5A0860218BD242BA5A8F71814
SHA256HashMatch : False
SHA512Hash      : 34955E74974888ABD576E05B142FA3BD88F16B0F17157B67C3F939CCF358CDDFE577FC3753F136A38E8A8DF3179DC1F284BA71D5BB52D52FA3B6C77ED088D471
SHA1Hash        : D5728664267618E26CB2EAF0E8CBC5A4C30A0ACB
SHA1HashMatch   : False
FileFilename    : duoauthproxy-2.4.17.exe
SHA512HashMatch : False
MD5HashMatch    : False

Use an alternative text for missing hashes.


.NOTES
NAME        :	Verify-FileHashes
VERSION     :  	1.0 
VERSION DATE:  	07/24/2016
AUTHOR      :  	Andrew Robinson (Phase2Automation)
CREDITS		:  	
			
.LINK
http://http://validate.whitescope.io/
.LINK
http://http://www.phase2automation.com
.LINK
https://github.com/bkrios/WhiteScope-Public

.INPUTS
Signatures for both the files of interest and reference data

.OUTPUTS
Array indicating hash matches per file
#>

	[cmdletbinding(SupportsShouldProcess=$True,ConfirmImpact="Low")]
	Param (
	  [Parameter(Position=0,Mandatory=$False,HelpMessage="Calculated signatures of target files.",
	  ValueFromPipeline=$True,parametersetname="nopipeline",ValueFromPipelineByPropertyName=$True)]
	  [ValidateNotNullorEmpty()]
	  [Alias("fs")]
	  [Object[]]$FileSignatures,

	  [Parameter(Mandatory=$False,HelpMessage="Signatures against which you should compare calculated file signatures.")]
	  [Alias("rs")]
	  [Object[]]$ReferenceSignatures,
	  
	  [Parameter(Mandatory=$False,HelpMessage="Alternative text to use if there is no matching file in the reference data.")]
	  [Alias("mht")]
	  [System.String]$MissingHashText = "N/A",
	  
	  [Parameter(Mandatory=$False,HelpMessage="Return an empty set of reference data that can be used to seed a file with the correct column names.")]
	  [System.Boolean]$GetEmptyReferenceData = $False
	  
	)

Begin
	{	
		Write-Host "$(Get-Date) Starting $($myinvocation.mycommand)"	
		
		if($PSCmdlet.ParameterSetName -eq "nopipeline")
    	{
	        $PathFromPipeline = $false
    	}
    	else
    	{
	        $PathFromPipeline = $true
    	}
		
		#Internal Globals
		$ResultsArray = @()
		$StartTime = Get-Date
		$PowerShellFileSystemPath = "Microsoft.PowerShell.Core\FileSystem::"

	} #Begin

Process
	{	
		if($GetEmptyReferenceData -eq $true)
		{
		
			Write-Verbose "$(Get-Date) Creating empty reference data"
		
			$EmptyReferenceData = @{
				FileFilename=""			            			          
				MD5Hash = ""
				SHA1Hash = ""
				SHA256Hash = ""
				SHA512Hash = ""							
			}
			
			$EmptyEntry = New-Object -TypeName PSObject -Property $EmptyReferenceData

			$ResultsArray+=$EmptyEntry
			
			return $ResultsArray
		}
	
		Write-Verbose "$(Get-Date) Verifying $($FileSignatures.Count) signatures"

		foreach($Signature in $FileSignatures)
		{
			#Create a base object with the information from the source signature
			$FileEntryProperties = @{}
			$FileEntryProperties = @{
				FileFilename=$Signature.FileFilename				            			          
				MD5Hash = $Signature.MD5Hash
				SHA1Hash = $Signature.SHA1Hash
				SHA256Hash = $Signature.SHA256Hash
				SHA512Hash = $Signature.SHA512Hash							
			}
			
			#Search the reference data for a match on FileFilename
			$ReferenceSignature = $ReferenceSignatures | Where-Object {$_.FileFilename -eq $Signature.FileFilename}
			
			$MatchProperties = @{}
			
			if($ReferenceSignature.FileFilename -eq $Signature.FileFilename)
			{
				#Found a matching filename so verify if there is a hash match
				$MatchProperties = @{
					MD5HashMatch = $(if($ReferenceSignature.MD5Hash.Length -gt 0) {$($ReferenceSignature.MD5Hash -eq $Signature.MD5Hash)} else {$MissingHashText})
					SHA1HashMatch = $(if($ReferenceSignature.SHA1Hash.Length -gt 0) {$($ReferenceSignature.SHA1Hash -eq $Signature.SHA1Hash)} else {$MissingHashText})
					SHA256HashMatch = $(if($ReferenceSignature.SHA256Hash.Length -gt 0) {$($ReferenceSignature.SHA256Hash -eq $Signature.SHA256Hash)} else {$MissingHashText})
					SHA512HashMatch = $(if($ReferenceSignature.SHA512Hash.Length -gt 0) {$($ReferenceSignature.SHA512Hash -eq $Signature.SHA512Hash)} else {$MissingHashText})
					}
			}
			else
			{
				#A filename match wasn't found so return the missing hash text when a matching file is not found
				$MatchProperties = @{
					MD5HashMatch = $MissingHashText
					SHA1HashMatch = $MissingHashText
					SHA256HashMatch = $MissingHashText
					SHA512HashMatch = $MissingHashText
					}
			}

			$FileEntryProperties += $MatchProperties 

			#Create a custom object with the accumulated entry properties
			$FileEntry = New-Object -TypeName PSObject -Property $FileEntryProperties

			$ResultsArray+=$FileEntry
		}

	} #Process
	
End
	{
	
	Write-Host "$(Get-Date) Completed $($myinvocation.mycommand)"
	
	#Return the Results Array
	return $ResultsArray
		
	} #end
	
} #End Function