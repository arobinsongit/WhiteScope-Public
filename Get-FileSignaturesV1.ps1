#requires -version 2.0
#Write-Host "This script requires Powershell Version 2.0 https://support.microsoft.com/kb/968929"

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
FileFullName         : C:\Windows\system.ini
MD5Hash              : 286A9EDB379DC3423A528B0864A0F111
FileLastWriteTimeUtc : 6/10/2009 9:08:04 PM
SHA1Hash             : 18DB3E3DFB6B1D4DC9BC2226109112466DE28DB0
EntryDate            : 12/21/2014 9:57:20 PM
FileFilename         : system.ini
FileCreationTimeUTC  : 7/14/2009 2:34:57 AM
SHA512Hash           : 588720A82941B44338196F1808B810FECBBC56CB9979628F1126048C28F80B946314092A8DD26F5E7ACA234B7163C4B9C1283A65C9B36BE2A4DA9966FEB8B2CB
FileSize             : 219

Return the signature information for the system.ini file

.EXAMPLE
PS C:\> Get-FileSignatures 'C:\Windows\explorer.exe' -IncludeVersionData $true
EntryDate                   : 12/21/2014 10:02:18 PM
FileCreationTimeUTC         : 12/8/2011 8:56:10 PM
FileFullName                : C:\Windows\explorer.exe
VersionInfoProduct          : 
MD5Hash                     : 332FEAB1435662FC6C672E25BEB37BE3
VersionInfoFileVersion      : 6.1.7600.16385 (win7_rtm.090713-1255)
FileLastWriteTimeUtc        : 12/8/2011 8:56:11 PM
VersionInfoFileDescription  : Windows Explorer
FileSize                    : 2871808
SHA256Hash                  : 6BED1A3A956A859EF4420FEB2466C040800EAF01EF53214EF9DAB53AEFF1CFF0
FileFilename                : explorer.exe
SHA1Hash                    : 5A49D7390EE87519B9D69D3E4AA66CA066CC8255
VersionInfoInternalName     : explorer
SHA512Hash                  : A685ADE424A5505A16E0F95D9DDD62B88E54F8911991D79687E7EF1582A7D3985DAFA44A35700E60CE8BF0879E784324DEC7E5D86B5E63AD820644CB978ACA
                              29
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
	  ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
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
	  [boolean]$IncludeAuthenticodeData = $false	 
	)

Begin
	{	
		Write-Verbose "$(Get-Date) Starting $($myinvocation.mycommand)"
		
		#Verify Powershell version
		$RequiredVersion = [Version]"2.0"
		if(-not (VerifyMajorVersion($RequiredVersion)))
		{
			#Bail on the cmdlet and do not run
			exit
		}
		
		#Internal Globals
		$ResultsArray = @()
		$StartTime = Get-Date
		$FileCount = 0

	} #Begin

Process
	{		
		Write-Verbose "$(Get-Date) Path List $PSPath"
		
		#Loop through the paths in the paths list
		foreach($Path in $PSPath)
			{						
			
				Write-Verbose "$(Get-Date) Getting files for $Path"
			
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
			
			
				foreach($File in $FilesList)
				{
			
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
						
						#Open the file as a stream
						$FileStream = $File.OpenRead()
									
						#Must reset stream position back to beginning of file before rereading.
						#Assumption is that this is faster than closing and re-opening.  But this theory has not been tested.

						$FileStream.Position = 0
						$MD5Hash = GetMD5HashAsString($FileStream)
						$FileStream.Position = 0
						$SHA1Hash = GetSHA1HashAsString($FileStream)			
						$FileStream.Position = 0
						$SHA256Hash = GetSHA256HashAsString($FileStream)
						$FileStream.Position = 0
						$SHA512Hash = GetSHA512HashAsString($FileStream)
						
						#Close the filestream, we're done with it
						$FileStream.Close() | Out-Null
						
						#Get the base properties for the file
						$BaseProperties = @{
							EntryDate=Get-Date
							FileFilename=$File.name
				            FileFullName=$File.Fullname
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
						
						#Create a custom object with the accumulated entry properties
						$FileEntry = New-Object -TypeName PSObject -Property $FileEntryProperties
						
						#Add to the array
						$ResultsArray += $FileEntry			
					}
					catch
					{
						#Write-Warning "(Get-Date) Failed to get file contents for $($file.name)."
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
	
	Write-Verbose "$(Get-Date) Total Duration $($Duration.ToString())"
	Write-Verbose "$(Get-Date) Total Files $FileCount"	
	$LogMessage = "$(Get-Date) Average Duration per file (ms) {0:N2}" -f ($AverageDuration)	
	Write-Verbose $LogMessage
	
	Write-Verbose "$(Get-Date) Completed $($myinvocation.mycommand)"
	
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

Function VerifyMajorVersion($RequiredVersion)
{	
	Write-Verbose "Verifying Powershell version"
	Write-Verbose "Required PowerShell version is $RequiredVersion"
	Write-Verbose "Current PowerShell version for this session is $($PSVersionTable.PSVersion)"
	
	If($PSVersionTable.PSVersion -lt $RequiredVersion)
	{
		Write-Error "Required PowerShell version is $RequiredVersion"
		Write-Error "Current PowerShell version for this session is $($PSVersionTable.PSVersion)"
		
		return $false
	}	
	else
	{
		return $true
	}	
}









