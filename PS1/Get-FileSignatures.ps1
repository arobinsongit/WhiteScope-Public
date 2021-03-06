#requires -Version 2.0

Function Get-FileSignatures
{
<#
.SYNOPSIS
Calculate and gather information on files in a filesystem

.DESCRIPTION
This command will gather and compute information on files in a filesystem.  The primary function
is to allow for fingerprinting a file, folder, or entire system for comparison against known good signatures
or comparison with previous signatures.

This code was originally created to support ICSWhiteList.com inventory of ICS related software installation media.

Special Note: You must have at least read privileges on the files and folder specified.

.PARAMETER PSPath
The filename and path of the file to compute. 

Aliases
	name
	file
	path

.PARAMETER ForceHiddenAndSystem
Include Hidden and System files.

Default
	True

Aliases
	force

.PARAMETER Recurse
Search the specified directory and all subdirectories. 

Default
	True

Aliases
	recurse
	includesubdirectories

.PARAMETER IncludeVersionData
Include additional data about file version.

Default
	False
	
Aliases
	versiondata

.PARAMETER IncludeAuthenticodeData
Include additional data about file authenticode signature. 
	
Default
	False

Aliases
	authenticodedata
	signaturedata

.EXAMPLE
PS C:\> Get-FileSignatures 'C:\Windows\system.ini'
SHA256Hash           : 6F533CCC79227E38F18BFC63BFC961EF4D3EE0E2BF33DD097CCF3548A12B743B
FileFullName         : 
FileRootPath         : 
MD5Hash              : 286A9EDB379DC3423A528B0864A0F111
FileLastWriteTimeUtc : 6/10/2009 9:08:04 PM
SHA1Hash             : 18DB3E3DFB6B1D4DC9BC2226109112466DE28DB0
EntryDate            : 12/27/2014 4:38:24 PM
FileFilename         : system.ini
FileCreationTimeUTC  : 7/14/2009 2:34:57 AM
SHA512Hash           : 588720A82941B44338196F1808B810FECBBC56CB9979628F1126048C28F80B946314092A8DD26F5E7ACA234B7163C4B9C1283A65C9B36BE2A4DA9966FEB8B2CB
FilePathWithoutRoot  : 
FileSize             : 219


Return the signature information for the system.ini file

.EXAMPLE
PS C:\> Get-FileSignatures 'C:\Windows\explorer.exe' -IncludeVersionData $true
EntryDate                   : 12/27/2014 4:39:05 PM
FilePathWithoutRoot         : 
FileFullName                : 
VersionInfoProduct          : 
MD5Hash                     : 332FEAB1435662FC6C672E25BEB37BE3
VersionInfoFileVersion      : 6.1.7600.16385 (win7_rtm.090713-1255)
FileLastWriteTimeUtc        : 12/8/2011 8:56:11 PM
VersionInfoFileDescription  : Windows Explorer
FileSize                    : 2871808
SHA256Hash                  : 6BED1A3A956A859EF4420FEB2466C040800EAF01EF53214EF9DAB53AEFF1CFF0
FileCreationTimeUTC         : 12/8/2011 8:56:10 PM
FileFilename                : explorer.exe
SHA1Hash                    : 5A49D7390EE87519B9D69D3E4AA66CA066CC8255
FileRootPath                : 
VersionInfoInternalName     : explorer
SHA512Hash                  : A685ADE424A5505A16E0F95D9DDD62B88E54F8911991D79687E7EF1582A7D3985DAFA44A35700E60CE8BF0879E784324DEC7E5D86B5E63AD820644CB978ACA29
VersionInfoProductVersion   : 6.1.7600.16385
VersionInfoOriginalFilename : EXPLORER.EXE.MUI

Get signature information for explore.exe and include version information.


.EXAMPLE
PS C:\> dir 'C:\Windows\System32\drivers\etc' | Get-FileSignatures | Export-Csv 'c:\temp\drivers_etc.csv'
Get signature information for all files in c:\windows\system32\drivers\etc and export to a CSV file

.NOTES
NAME        :	Get-FileSignatures
VERSION     :  	1.0 
VERSION DATE:  	12/21/2014
AUTHOR      :  	Andrew Robinson (Phase2Automation)
CREDITS		:  	Thanks to Billy Rios for creating ICS Whitelist and inspiring this work to support the larger effort.
			:  	Thanks to Jeffery Hicks and his Get-FileHash function provided at http://jdhitsolutions.com/blog/2011/03/get-file-hash/ 
			
NAME        :	Get-FileSignatures
VERSION     :  	1.1
VERSION DATE:  	12/21/2014
AUTHOR      :  	Andrew Robinson (Phase2Automation)
REVISIONS	:	Added Progress Tracking			

NAME        :	Get-FileSignatures
VERSION     :  	1.2
VERSION DATE:  	12/27/2014
AUTHOR      :  	Andrew Robinson (Phase2Automation)
REVISIONS	:	Made Progress Tracking more granular
				Added $IncludeRootPath to allow for including or excluding root path information for security considerations
				Added a few Write-Host to give output information instead of making verbose
			

.LINK
http://http://www.icswhitelist.com/
.LINK
http://http://www.phase2automation.com 

.INPUTS
Strings for filenames or folders to include in search

.OUTPUTS
Array of custom objects with signature details based on input value
#>

	[cmdletbinding(SupportsShouldProcess=$True,ConfirmImpact="Low")]
	Param (
	  [Parameter(Position=0,Mandatory=$True,HelpMessage="Enter File Path(s)",
	  ValueFromPipeline=$True,parametersetname="nopipeline",ValueFromPipelineByPropertyName=$True)]
	  [ValidateNotNullorEmpty()]
	  [Alias("name","file","path")]
	  [string[]]$PSPath,

	  [Parameter(Mandatory=$False,HelpMessage="Force scan to include hidden and system files.")]
	  [Alias("force")]
	  [boolean]$ForceHiddenAndSystem = $True,
	  
	  [Parameter(Mandatory=$False,HelpMessage="Include subdirectories.")]
	  [Alias("recurse,includesubdirectories")]
	  [boolean]$Recurse = $True,

	  [Parameter(Mandatory=$False,HelpMessage="Include file version data.")]
	  [Alias("versiondata")]
	  [boolean]$IncludeVersionData = $false,
	  
	  [Parameter(Mandatory=$False,HelpMessage="Include digital certificate signature data.")]
	  [Alias("authenticodedata,signaturedata")]
	  [boolean]$IncludeAuthenticodeData = $false,	 
	  
	  [Parameter(Mandatory=$False,HelpMessage="Include root path information in the output. Consider this might be a security risk so use with caution.")]	  
	  [Alias("includerootinformation")]
	  [boolean]$IncludeRootPath = $false	 	  
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
		$FileCount = 0
		$PowerShellFileSystemPath = "Microsoft.PowerShell.Core\FileSystem::"

	} #Begin

Process
	{		
		Write-Verbose "$(Get-Date) Path List $PSPath"
				
		#Loop through the paths in the paths list
		foreach($Path in $PSPath)
			{									
				Write-Verbose "$(Get-Date) Getting files for $Path"
				
				$Path = AppendTrailingSlash -Path $Path
			
				# Get the files for this path, excluding directories
				if($Recurse)
				{
					if($ForceHiddenAndSystem)
					{
						$FilesList = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction Stop | where { ! $_.PSIsContainer }
					}
					else
					{
						$FilesList = Get-ChildItem -Path $Path -Recurse -ErrorAction Stop | where { ! $_.PSIsContainer }
					}		
				} # if($Recurse)
				else
				{
					if($ForceHiddenAndSystem)
					{
						$FilesList = Get-ChildItem -Path $Path -Force -ErrorAction Stop | where { ! $_.PSIsContainer }
					}
					else
					{
						$FilesList = Get-ChildItem -Path $Path -ErrorAction Stop | where { ! $_.PSIsContainer }
					}
				} # if($Recurse)
								
				# Calculate total file size for this path, in MB.  Don't want to run the risk of overflowing INT32
				$totalFileSize = ($FilesList | Measure-Object -Sum Length).Sum/1MB
		
				Write-Verbose "Total File Size to Analyze for $Path is $totalFileSize MB"
				
				#Initialize running total file size
				$runningTotalFileSize = 0

				foreach($File in $FilesList)
				{
			
					<#
					Write out the progress at the beginning.  
					Don't increment running total file size until the end b/c we haven't actually made progress until we finish this loop.
					Also protect against overruns past 100% with a simple min function
					#>
					
					$pctComplete = [math]::min(($runningTotalFileSize/$totalFileSize)*100.0,100.0)
					Write-Progress -Activity "Analyzing $Path" -Status "Processing $File" -CurrentOperation "" -PercentComplete $pctComplete
					
					Write-Verbose "$(Get-Date) Verifying $File is valid"
				
					# Make sure this is a valid file
					if (-not (Test-Path -Path $File.PSPath))
					{
						Write-Warning "$(Get-Date) $File is not a valid file.  Skipping."
						# go to next file
						continue			
					}

					# Make sure the file is not zero length
					if ($File.length -le 0)
					{
						Write-Warning "$(Get-Date) $File is zero length.  Skipping."
						# go to next file
						continue			
					}
										
					Write-Verbose "$(Get-Date) $File is valid.  Beginning to create signature."
					
					try
					{					

						#Increment the file count
						$FileCount += 1
						
						$thisFileSize = $File.Length/1MB
						
						#Open the file as a stream
						$FileStream = $File.OpenRead()
									
						#Must reset stream position back to beginning of file before rereading.
						#Assumption is that this is faster than closing and re-opening.  But this theory has not been tested.

						$FileStream.Position = 0
						$MD5Hash = GetMD5HashAsString($FileStream)
						Write-Progress -Activity "Analyzing $Path" -Status "Calculating Signature for $File" -CurrentOperation "Calculating MD5 Hash" -PercentComplete $pctComplete
						
						<# 
						Add to Running Size after processing.  Remember we are working in MB						
						Take the total file size and divide into 4 pieces + 1 small piece.
						We assume the hashing takes approximately the same time becaue the time to read
						the file is much more than the time to actually calculate the hash.
						This has been verified by testing  all files in my c:\windows\system32\drivers directory
						The time to execute the different algorithms was essentially the same.. at least for the purposes
						of tracking progress
						#>

						$runningTotalFileSize += $thisFileSize * 0.24;
						
						$pctComplete = [math]::min(($runningTotalFileSize/$totalFileSize)*100.0,100.0)
						Write-Progress -Activity "Analyzing $Path" -Status "Calculating Signature for $File" -CurrentOperation "Calculating SHA1 Hash" -PercentComplete $pctComplete
						
						$FileStream.Position = 0
						$SHA1Hash = GetSHA1HashAsString($FileStream)			
						$runningTotalFileSize += $thisFileSize * 0.24;

						$pctComplete = [math]::min(($runningTotalFileSize/$totalFileSize)*100.0,100.0)
						Write-Progress -Activity "Analyzing $Path" -Status "Calculating Signature for $File" -CurrentOperation "Calculating SHA256 Hash" -PercentComplete $pctComplete
						
						$FileStream.Position = 0
						$SHA256Hash = GetSHA256HashAsString($FileStream)
						$runningTotalFileSize += $thisFileSize * 0.24;

						$pctComplete = [math]::min(($runningTotalFileSize/$totalFileSize)*100.0,100.0)
						Write-Progress -Activity "Analyzing $Path" -Status "Calculating Signature for $File" -CurrentOperation "Calculating SHA512 Hash" -PercentComplete $pctComplete

						$FileStream.Position = 0
						$SHA512Hash = GetSHA512HashAsString($FileStream)
						$runningTotalFileSize += $thisFileSize * 0.24;

						$pctComplete = [math]::min(($runningTotalFileSize/$totalFileSize)*100.0,100.0)						
						Write-Progress -Activity "Analyzing $Path" -Status "Calculating Signature for $File" -CurrentOperation "Retrieving Additional File Data" -PercentComplete $pctComplete
						
						#Close the filestream, we're done with it
						$FileStream.Close() | Out-Null
						
						#Calculate some pieces of the results that may or may not be included
						If($IncludeRootPath)
						{
							$FileFullName = $File.Fullname.ToLower()
							$FileSearchRootPath = $Path.ToLower() 
						}
						else
						{
							$FileFullName = ""
							$FileRootPath = ""
						}
												
						# Calculate file path without search root
						
						# If the path is fed in through the pipeline with a DIR command then you get some strange leading characters.  Trim thos off
						$TrimmedPath = TrimLeadingCharacters -InputString $Path.ToLower() -LeadingCharacters $PowerShellFileSystemPath.ToLower()
						
						# Add a trailing \ to the path if it's not already there and Path is a directory
						$TrimmedPath = AppendTrailingSlash -Path $TrimmedPath						
						
						#Now trim the search path off of the filename leaving just the relevant part with respect to the search path
						$FilePathWithoutRoot = TrimLeadingCharacters -InputString $File.Fullname.ToLower() -LeadingCharacters $TrimmedPath															
												
						#Get the base properties for the file
						$BaseProperties = @{
							EntryDate=Get-Date
							FileFilename=$File.Name.ToLower()
				            FileFullName=$FileFullName
							FileSearchRootPath=$FileSearchRootPath						
							FilePathWithoutRoot=$FilePathWithoutRoot				
							FileSize=$File.length												
				            FileCreationTimeUTC = $File.CreationTimeUtc
							FileLastWriteTimeUtc = $File.LastWriteTimeUtc	            
							MD5Hash = $MD5Hash
							SHA1Hash = $SHA1Hash
							SHA256Hash = $SHA256Hash
							SHA512Hash = $SHA512Hash
							}
						
						$FileEntryProperties =@{}
						$FileEntryProperties += $BaseProperties
									
						#if we include version data then get the data and add to $FileEntryProperties properties array
						if($IncludeVersionData)
							{
							
							Write-Progress -Activity "Analyzing $Path" -Status "Calculating Signature for $File" -CurrentOperation "Retrieving File Version Data" -PercentComplete $pctComplete
							
							$VersionInfo = $File | Select-Object -ExpandProperty VersionInfo
							
							$VersionProperties =@{
								VersionInfoInternalName = $VersionInfo.InternalName
								VersionInfoOriginalFilename = $VersionInfo.OriginalFilename
								VersionInfoFileVersion = $VersionInfo.FileVersion
								VersionInfoFileDescription = $VersionInfo.FileDescription
								VersionInfoProduct = $VersionInfo.Product
								VersionInfoProductVersion = $VersionInfo.ProductVersion														
								}
								
								#Add to the running properties 
								$FileEntryProperties += $VersionProperties				
							}
						
						#if we include Authenticode data then get the data and add to the $FileEntryProperties
						if($IncludeAuthenticodeData)
							{
							
							Write-Progress -Activity "Analyzing $Path" -Status "Calculating Signature for $File" -CurrentOperation "Retrieving Signature Data" -PercentComplete $pctComplete
							
							$AuthenticodeSignature = Get-AuthenticodeSignature -FilePath $File.Fullname
							
							$AuthenticodeProperties = @{				
								AuthenticodeSignatureStatus = $AuthenticodeSignature.Status
								AuthenticodeSignatureStatusMessage = $AuthenticodeSignature.StatusMessage								
								AuthenticodeSignatureSignerCertificateSubject = $AuthenticodeSignature.SignerCertificate.Subject
								AuthenticodeSignatureSignerCertificateIssuer = $AuthenticodeSignature.SignerCertificate.Issuer								
								AuthenticodeSignatureSignerCertificateSerial = $AuthenticodeSignature.SignerCertificate.SerialNumber
								AuthenticodeSignatureSignerCertificateThumbprint = $AuthenticodeSignature.SignerCertificate.Thumbprint
								AuthenticodeSignatureSignerCertificateNotBefore = $AuthenticodeSignature.SignerCertificate.NotBefore
								AuthenticodeSignatureSignerCertificateNotAFter = $AuthenticodeSignature.SignerCertificate.NotAfter												
								AuthenticodeSignatureTimestamperCertificateSubject = $AuthenticodeSignature.TimestamperCertificate.Subject
								AuthenticodeSignatureTimestamperCertificateIssuer = $AuthenticodeSignature.TimestamperCertificate.Issuer
								AuthenticodeSignatureTimestamperCertificateSerial = $AuthenticodeSignature.TimestamperCertificate.SerialNumber							
								AuthenticodeSignatureTimestamperCertificateThumbprint = $AuthenticodeSignature.TimestamperCertificate.Thumbprint							
								AuthenticodeSignatureTimestamperCertificateNotBefore = $AuthenticodeSignature.TimestamperCertificate.NotBefore
								AuthenticodeSignatureTimestamperCertificateNotAfter = $AuthenticodeSignature.TimestamperCertificate.NotAfter
								}
								
								#Add to the running properties 
								$FileEntryProperties += $AuthenticodeProperties				
							}
						
						$runningTotalFileSize += $thisFileSize * 0.04;
						
						#Create a custom object with the accumulated entry properties
						$FileEntry = New-Object -TypeName PSObject -Property $FileEntryProperties
						
						#Add to the array
						$ResultsArray += $FileEntry		
						
						Write-Progress -Activity "Analyzing $Path" -Status "Calculating Signature for $File" -CurrentOperation "Complete" -PercentComplete $pctComplete						
												
					}
					catch
					{						
			            Write-Warning "$(Get-Date) File $File Error Message : $_.Exception.Message"
						Continue
					}				
				
				} # foreach($File in $FilesList)
			} #foreach($Path in $PathsList)
	} #Process
	
End
	{
	
	#Calculate total script duration	
	$Duration = New-TimeSpan $StartTime (Get-Date)		
	
	#Calculate average duration
	$AverageDuration = ($($Duration.TotalMilliseconds) / $FileCount)
	
	Write-Host "$(Get-Date) Total Duration $($Duration.ToString())"
	Write-Host "$(Get-Date) Total Files $FileCount"	
	$LogMessage = "$(Get-Date) Average Duration per file (ms) {0:N2}" -f ($AverageDuration)	
	Write-Host $LogMessage
	
	Write-Host "$(Get-Date) Completed $($myinvocation.mycommand)"
	
	#Return the Results Array
	return $ResultsArray
		
	} #end
	
} #End Function


Function GetProvider($Type)
{
    Switch ($Type) {
    "sha1"  {
                $provider = New-Object System.Security.Cryptography.SHA1CryptoServiceProvider
            }
    "sha256"  {
                $provider = New-Object System.Security.Cryptography.SHA256CryptoServiceProvider
            }
    "md5"   {
                $provider = New-Object System.Security.Cryptography.MD5CryptoServiceProvider
            }
    "sha512"   {
                $provider = New-Object System.Security.Cryptography.SHA512CryptoServiceProvider
            }			
     }
	 
	 return $provider
}

Function GetMD5HashAsString($inStream)
{
	$provider = GetProvider("MD5")	
	return GetHashBytesAsString($provider.ComputeHash($inStream))
}

Function GetSHA1HashAsString($inStream)
{
	$provider = GetProvider("SHA1")
	return GetHashBytesAsString($provider.ComputeHash($inStream))
}

Function GetSHA256HashAsString($inStream)
{
	$provider = GetProvider("SHA256")
	return GetHashBytesAsString($provider.ComputeHash($inStream))
}

Function GetSHA512HashAsString($inStream)
{
	$provider = GetProvider("SHA512")
	return GetHashBytesAsString($provider.ComputeHash($inStream))
}

Function GetHashBytesAsString($localhashBytes)
{
	$localhashString = ""
	
	foreach ($byte in $localhashBytes)
   	{
    	#calculate the hash
        $localhashString+=$byte.ToString("X2")
    }	
	
	return $localhashString
}

Function TrimLeadingCharacters($InputString, $LeadingCharacters)
{	
	if($InputString.Length -ge $LeadingCharacters.Length)
	{
		#First check to see if those leading characters really are the leading characters
		if($InputString.Substring(0,$LeadingCharacters.Length) -eq $LeadingCharacters)
		{
			return $InputString.Substring($LeadingCharacters.Length,$InputString.Length-($LeadingCharacters.Length))
		}
		else
		{
			return $InputString
		}
	}
	else
	{
		return $InputString
	}
}

Function AppendTrailingSlash($Path)
{
	$returnValue = $Path
	
	# Append a trailing \ if the path is a directory.  This is used in later code separates the root path and filename with associated path
	if((Get-Item $Path) -is [System.IO.DirectoryInfo])
	{
		if($path.Substring($path.Length - 1,1) -ne '\')
		{
			$returnValue += '\'
		}
	}
	
	return $returnValue
}
