﻿Function Get-RepositoryData
{
<#
.SYNOPSIS
Retrieve information from online repository for a set of signature

.DESCRIPTION
This command will take a list of file signatures created by the Get-FileSignatures function and retrieve
associated details from the ICSWhitelist.com online repository.  This data can then be processed to confirm
if a file hash matches the online information.

This code was originally created to support ICSWhiteList.com inventory of ICS related software installation media.

Special Note: 

.PARAMETER Signatures
The signatures object from the Get-FileSignatures function

.PARAMETER RootURI
The root URI for the API to call

Default
	"https://validate.whitescope.io/api/v1/json/"

.PARAMETER HashAlgosToVerify
An array of Hash Algorithms to verify against.  Acceptable values are MD5, SHA1, SHA256, SHA512. One or more values may be supplied.

Default
	@("MD5","SHA1")

.EXAMPLE
PS C:\> $RepositoryData = Get-FileSignatures 'C:\Program Files (x86)\Notepad++\notepad++.exe' -IncludeVersionData $true -IncludeAuthenticodeData $false -IncludeRootPath $false  | Get-RepositoryData

Get File Signature information for notepad++.exe and then send to this function via pipeline

PS C:\> $Signatures = Get-FileSignatures 'C:\Program Files (x86)\Notepad++\notepad++.exe' -IncludeVersionData $true -IncludeAuthenticodeData $false -IncludeRootPath $false  
PS C:\> Get-RepositoryData -Signatures $Signatures -HashAlgosToVerify @("MD5","SHA1")

Get the signatures in a result variable and feed that to function via -Signatures.  Also specify to use both MD5 and SHA1 hashes to send to API for verification

PS C:\> Get-FileSignatures 'C:\Program Files (x86)\Notepad++\notepad++.exe' -IncludeVersionData $true -IncludeAuthenticodeData $false -IncludeRootPath $false | Export-Csv "c:\temp\signatures.csv"
PS C:\> $Signatures = Import-Csv -Path "c:\temp\signatures.csv"
PS C:\> Get-RepositoryData -Signatures $Signatures

Get file signatures and export to CSV.  Then import the CSV into a variable and send that to this function

.LINK
http://www.icswhitelist.com/
.LINK
http://www.phase2automation.com 

.INPUTS
Signature data from the Get-FileSignatures function or of the same form, possibly from a CSV load

.OUTPUTS
Array of custom objects with matched details from online repository
#>
	[cmdletbinding(SupportsShouldProcess=$True,ConfirmImpact="Low")]
	Param (
	  [Parameter(
	  	Position=0,
		Mandatory=$True,
		HelpMessage="File Signatures Object",
	  	ValueFromPipeline=$True,
		parametersetname="nopipeline",
		ValueFromPipelineByPropertyName=$True
		)
		]
	  [ValidateNotNullorEmpty()]	  
	  [System.Array]$Signatures,

	  [Parameter(Mandatory=$False,HelpMessage="The root URI for the API to call")]	  
	  [string]$RootURI = "https://validate.whitescope.io/api/v1/json/",
	  
	  [Parameter(Mandatory=$False,HelpMessage="Array of hash algorithms to verify")]	  
	  [string[]]$HashAlgosToVerify = @("MD5")
	)
<#
We track separate arrays because the first element in the array sets all of the field names
so if the first addition does not have a match in the repo then the additional repo attributes 
won't get added on subsequent appends to the array
#>

Begin
	{	
		Write-Host "$(Get-Date) Starting $($myinvocation.mycommand)"	
		
		if($PSCmdlet.ParameterSetName -eq "nopipeline")
    	{
	        $SignaturesFromPipeline = $false
    	}
    	else
    	{
	        $SignaturesFromPipeline = $true
    	}
		
		#Internal Globals		
		$StartTime = Get-Date
		$SignatureCount = 0		
		$PowerShellFileSystemPath = "Microsoft.PowerShell.Core\FileSystem::"
		
		$SignaturesWithMatchArray = @()
		$SignaturesWithNoMatchArray = @()
		$SignaturesCombinedArray = @()

	} #Begin


Process
	{
		# Loop through all of the signatures
		foreach($Signature in $Signatures)
		{

		$x = $x + 1

			# Loop through each of the hash types to check
			foreach($HashAlgo in $HashAlgosToVerify)
			{	
				#Default to blank
				$HashValue = ""
				
				#Get the correct entry from the signature based on the algorithm
				switch($HashAlgo)
					{
						"MD5" 		{$HashValue =  $Signature.MD5Hash}
						"SHA1" 		{$HashValue =  $Signature.SHA1Hash}
						"SHA256" 	{$HashValue =  $Signature.SHA256Hash}
						"SHA512" 	{$HashValue =  $Signature.SHA512Hash}
						default 	{$HashValue =  ""}
					}
						
				#Force this to a new object so if we get an error we don't have old data left from the last loop iteration
				$APICallResult = New-Object -TypeName PSObject
				
				#If we actually have a hash value then invoke the API
				if($HashValue -ne "")
				{
					try
						{
							#Build the URI and use as a variable.  It's a little tricker to build in-lin
							$CompleteURI = $RootURI + $HashValue
														
							#We use an action of continue so we don't bomb out the script if we have a bad hash or some other form of a bad call
							$APICallResult = Invoke-WebRequest -Method Get -Uri $CompleteURI -ErrorAction Continue
						}
					catch
						{
							# Do nothing.  Not getting a result or erroring count 
							# Just depend on the inspection of the status code below
							$Errors = 1
						}

					if($APICallResult.StatusCode -eq 200)
					{	
					
						#Convert the JSON into a custom powershell object
						$APICallResultObject = ConvertFrom-Json -InputObject $APICallResult
						
						#If we have entries then loop through them
						if($APICallResultObject.Length -ge 1)				
						{
							foreach($Result in $APICallResultObject)					
							{				
							
								<#
								Get a single instance of the signature object
								This avoids issues when we have two API results but a single signature object
								Also note the .PSObject.Copy() call.  When just using = it actually set a reference, not a copy
								so when I add member properties to what I think is the newly created object it's actually
								setting properties on the original b/c I am using a reference, not a copy.
								#>
								
								$SignatureObjectForSingleAPIResult = $Signature.PSObject.copy()
														
								#Loop through the API result properties and add members to the new object
								foreach ( $Property in $Result.psobject.Properties)
									{        				
									$SignatureObjectForSingleAPIResult | Add-Member -Name "Repository$($Property.Name)" -Value $Property.Value -MemberType NoteProperty
									}
															
								#Add to the array
								$SignaturesWithMatchArray += $SignatureObjectForSingleAPIResult
							}
						}
						else
						{
							$SignaturesWithNoMatchArray += $Signature
						}
						
					} # if($APICallResult.StatusCode -eq 200)
					else
					{			
						Write-Host "API error occured while processing $($Signature.FileFilename)" -ForegroundColor Red
					} # if($APICallResult.StatusCode -eq 200)
				} # if($HashValue -ne "")
			} # foreach($HashAlgo in $HashesToVerify)
		} # foreach($Signature in $Signatures)
	} # process
		
End
	{	
		#Combine the results to a single array
		$SignaturesCombinedArray = $SignaturesWithMatchArray.PSObject.Copy()
		$SignaturesCombinedArray += $SignaturesWithNoMatchArray
		
		#Calculate total script duration	
		$Duration = New-TimeSpan $StartTime (Get-Date)		
		
		#Calculate average duration
		$AverageDuration = ($($Duration.TotalMilliseconds) / $SignaturesCombinedArray.Length)
		
		Write-Host "$(Get-Date) Total Duration $($Duration.ToString())"
		Write-Host "$(Get-Date) Total Items $($SignaturesCombinedArray.Length)"	
		$LogMessage = "$(Get-Date) Average Duration per item (ms) {0:N2}" -f ($AverageDuration)	
		Write-Host $LogMessage
		
		Write-Host "$(Get-Date) Completed $($myinvocation.mycommand)"
		
		#Return the Results Array
		return $SignaturesCombinedArray		
	} #end
	
} #End Function
