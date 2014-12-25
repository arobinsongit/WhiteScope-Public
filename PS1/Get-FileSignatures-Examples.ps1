cls

.'d:\ICSWhiteList\Get-FileSignaturesV1.1.ps1'

#Execute a dir command and pipeline the results into the function, then take the results and export to csv
dir 'C:\Windows\System32\drivers' | Get-FileSignatures | Export-Csv 'c:\temp\drivers_etc.csv'

#Call function directly and export results to csv
Get-FileSignatures 'C:\Windows\System32\drivers' -IncludeVersionData $true | Export-Csv "c:\temp\file.csv"

#Call function directly, print verbose messages, and export results to a grid view displayed on the screen.  This directory will have many files with interesting version and signing data
Get-FileSignatures 'C:\Windows\System32\drivers' -IncludeVersionData $true -IncludeAuthenticodeData $true  | Out-GridView

#Get help information for this function
Get-Help Get-FileSignatures -Detailed 