<#
.SYNOPSIS
    Active Directory User Synchronization Script

.DESCRIPTION
    Part of an AD synchronization suite that maintains user accounts between 
    source and target domains. Handles user creation, updates, and removal 
    with safety thresholds and comprehensive logging.
    
    Start-ADSync.ps1: 
    Main orchestration script that coordinates user synchronization between domains.

.AUTHOR
    James Lunardi
    https://www.linkedin.com/in/jameslunardi/

.VERSION
    1.0

.DATE
    June 2019
#>

. "C:\Scripts\ADSync\Remove-TargetUser.ps1"
. "C:\Scripts\ADSync\Add-TargetUser.ps1"
. "C:\Scripts\ADSync\Update-TargetUser.ps1"
. "C:\Scripts\ADSync\General-Functions.ps1"

$LogTime = Get-Date -Format "MM-dd-yyyy_HH"
$folder = "C:\Scripts\ADSync\Logs\"
$logname = "ADSync-$LogTime-log.txt"

Start-Transcript -path "C:\Scripts\ADSync\Logs\transcript-$LogTime.log" -append

$sourceusers = Export-SourceUsers
$targetusers = Export-TargetUsers

Write-Host "Number of users found in Source: $($sourceusers.count)"
Write-Host "Number of users found in Target: $($targetusers.count)"

$sourcematchedusers = [system.Collections.ArrayList]@()
$targetmatchedusers = [system.Collections.ArrayList]@()
$addusers = [System.Collections.ArrayList]@()
$removeusers = [System.Collections.ArrayList]@()
$updateusers = [System.Collections.ArrayList]@()
$expiredusers = [System.Collections.ArrayList]@()
$inactiveusers = [System.Collections.ArrayList]@()

# Compare users in Source with Users in Target to generate a list of matched users and a list of users to add
Write-Host "Checking if Source user matches with a Target user. Creating list of matched users and a list of missing users."
ForEach($sourceuser in $sourceusers){

    # Is Source User in the Target Users list
    $match = $null
    $match = [array]::IndexOf($targetusers.EmployeeID, $sourceuser.EmployeeID)

    IF($match -ne -1){

        $targetmatchedusers += $targetusers[$match]
        $count = $targetmatchedusers.count - 1
        $sourceuser | Add-Member -NotePropertyName Match -NotePropertyValue $count
        $sourcematchedusers += $sourceuser

    } Else {

        $addusers += $sourceuser

    } # End If/Else

} # End ForEach

# Check each attribute on a matched user to see if an update is needed, add updates required to array
Write-Host "Checking matched users to see if an update is needed."
ForEach($user in $sourcematchedusers){

    If($user.mail -ne $targetmatchedusers[$user.match].mail){
        
        $updateusers += [PSCustomObject]@{
            DistinguishedName = $targetmatchedusers[$user.match].DistinguishedName
            SamAccountName = $targetmatchedusers[$user.match].SamAccountName
            Attribute = "mail"
            NewValue = $user.mail
            OldValue = $targetmatchedusers[$user.match].mail
        }

    } # End If
    
    If($user.GivenName -ne $targetmatchedusers[$user.match].GivenName){

        $updateusers += [PSCustomObject]@{
            DistinguishedName = $targetmatchedusers[$user.match].DistinguishedName
            SamAccountName = $targetmatchedusers[$user.match].SamAccountName
            Attribute = "GivenName"
            NewValue = $user.GivenName
            OldValue = $targetmatchedusers[$user.match].GivenName
        }

    } # End If
    
    If($user.Surname -ne $targetmatchedusers[$user.match].Surname){

        $updateusers += [PSCustomObject]@{
            DistinguishedName = $targetmatchedusers[$user.match].DistinguishedName
            SamAccountName = $targetmatchedusers[$user.match].SamAccountName
            Attribute = "Surname"
            NewValue = $user.Surname
            OldValue = $targetmatchedusers[$user.match].Surname
        }

    } # End If
    
    If(($user.Enabled -ne $targetmatchedusers[$user.match].Enabled) -and ($user.Enabled -eq $false)){
        
        $updateusers += [PSCustomObject]@{
            DistinguishedName = $targetmatchedusers[$user.match].DistinguishedName
            SamAccountName = $targetmatchedusers[$user.match].SamAccountName
            Attribute = "Enabled"
            NewValue = $user.Enabled
            OldValue = $targetmatchedusers[$user.match].Enabled
        }

    } # End If
    
    If($user.AccountExpirationDate -ne $targetmatchedusers[$user.match].AccountExpirationDate){
        
        $updateusers += [PSCustomObject]@{
            DistinguishedName = $targetmatchedusers[$user.match].DistinguishedName
            SamAccountName = $targetmatchedusers[$user.match].SamAccountName
            Attribute = "AccountExpirationDate"
            NewValue = $user.AccountExpirationDate
            OldValue = $targetmatchedusers[$user.match].AccountExpirationDate
        }

    } # End If
    
    If($user.Title -ne $targetmatchedusers[$user.match].Title){

        $updateusers += [PSCustomObject]@{
            DistinguishedName = $targetmatchedusers[$user.match].DistinguishedName
            SamAccountName = $targetmatchedusers[$user.match].SamAccountName
            Attribute = "Title"
            NewValue = $user.Title
            OldValue = $targetmatchedusers[$user.match].Title
        }

    } # End If
    
    If($user.Office -ne $targetmatchedusers[$user.match].Office){

        $updateusers += [PSCustomObject]@{
            DistinguishedName = $targetmatchedusers[$user.match].DistinguishedName
            SamAccountName = $targetmatchedusers[$user.match].SamAccountName
            Attribute = "Office"
            NewValue = $user.Office
            OldValue = $targetmatchedusers[$user.match].Office
        }

    } # End If
    
    If($user.Department -ne $targetmatchedusers[$user.match].Department){

        $updateusers += [PSCustomObject]@{
            DistinguishedName = $targetmatchedusers[$user.match].DistinguishedName
            SamAccountName = $targetmatchedusers[$user.match].SamAccountName
            Attribute = "Department"
            NewValue = $user.Department
            OldValue = $targetmatchedusers[$user.match].Department
        }

    } # End If
    
    If($user.l -ne $targetmatchedusers[$user.match].l){

        $updateusers += [PSCustomObject]@{
            DistinguishedName = $targetmatchedusers[$user.match].DistinguishedName
            SamAccountName = $targetmatchedusers[$user.match].SamAccountName
            Attribute = "l"
            NewValue = $user.l
            OldValue = $targetmatchedusers[$user.match].l
        }

    } # End If
    
    If($user.'msDS-cloudExtensionAttribute1' -ne $targetmatchedusers[$user.match].'msDS-cloudExtensionAttribute1'){

        $updateusers += [PSCustomObject]@{
            DistinguishedName = $targetmatchedusers[$user.match].DistinguishedName
            SamAccountName = $targetmatchedusers[$user.match].SamAccountName
            Attribute = "msDS-cloudExtensionAttribute1"
            NewValue = $user.'msDS-cloudExtensionAttribute1'
            OldValue = $targetmatchedusers[$user.match].'msDS-cloudExtensionAttribute1'
        }

    } # End If
    
    If($user.'msDS-cloudExtensionAttribute2' -ne $targetmatchedusers[$user.match].'msDS-cloudExtensionAttribute2'){

        $updateusers += [PSCustomObject]@{
            DistinguishedName = $targetmatchedusers[$user.match].DistinguishedName
            SamAccountName = $targetmatchedusers[$user.match].SamAccountName
            Attribute = "msDS-cloudExtensionAttribute2"
            NewValue = $user.'msDS-cloudExtensionAttribute2'
            OldValue = $targetmatchedusers[$user.match].'msDS-cloudExtensionAttribute2'
        }

    } # End If
    
    If($user.'msDS-cloudExtensionAttribute3' -ne $targetmatchedusers[$user.match].'msDS-cloudExtensionAttribute3'){

        $updateusers += [PSCustomObject]@{
            DistinguishedName = $targetmatchedusers[$user.match].DistinguishedName
            SamAccountName = $targetmatchedusers[$user.match].SamAccountName
            Attribute = "msDS-cloudExtensionAttribute3"
            NewValue = $user.'msDS-cloudExtensionAttribute3'
            OldValue = $targetmatchedusers[$user.match].'msDS-cloudExtensionAttribute3'
        }

    } # End If
    
    If($user.'msDS-cloudExtensionAttribute6' -ne $targetmatchedusers[$user.match].'msDS-cloudExtensionAttribute6'){

        $updateusers += [PSCustomObject]@{
            DistinguishedName = $targetmatchedusers[$user.match].DistinguishedName
            SamAccountName = $targetmatchedusers[$user.match].SamAccountName
            Attribute = "msDS-cloudExtensionAttribute6"
            NewValue = $user.'msDS-cloudExtensionAttribute6'
            OldValue = $targetmatchedusers[$user.match].'msDS-cloudExtensionAttribute6'
        }

    } # End If
    
    If($user.'msDS-cloudExtensionAttribute7' -ne $targetmatchedusers[$user.match].'msDS-cloudExtensionAttribute7'){

        $updateusers += [PSCustomObject]@{
            DistinguishedName = $targetmatchedusers[$user.match].DistinguishedName
            SamAccountName = $targetmatchedusers[$user.match].SamAccountName
            Attribute = "msDS-cloudExtensionAttribute7"
            NewValue = $user.'msDS-cloudExtensionAttribute7'
            OldValue = $targetmatchedusers[$user.match].'msDS-cloudExtensionAttribute7'
        }

    } # End If
    
    If($user.'msDS-cloudExtensionAttribute10' -ne $targetmatchedusers[$user.match].'msDS-cloudExtensionAttribute10'){

        $updateusers += [PSCustomObject]@{
            DistinguishedName = $targetmatchedusers[$user.match].DistinguishedName
            SamAccountName = $targetmatchedusers[$user.match].SamAccountName
            Attribute = "msDS-cloudExtensionAttribute10"
            NewValue = $user.'msDS-cloudExtensionAttribute10'
            OldValue = $targetmatchedusers[$user.match].'msDS-cloudExtensionAttribute10'
        }

    } # End If
    
    If($user.'msDS-cloudExtensionAttribute11' -ne $targetmatchedusers[$user.match].'msDS-cloudExtensionAttribute11'){
        
        $updateusers += [PSCustomObject]@{
            DistinguishedName = $targetmatchedusers[$user.match].DistinguishedName
            SamAccountName = $targetmatchedusers[$user.match].SamAccountName
            Attribute = "msDS-cloudExtensionAttribute11"
            NewValue = $user.'msDS-cloudExtensionAttribute11'
            OldValue = $targetmatchedusers[$user.match].'msDS-cloudExtensionAttribute11'
        }

    } # End If

    If(($user.DistinguishedName -like "*Leavers*") -and ($targetmatchedusers[$user.match] -notlike "*Leavers*")){

        $updateusers += [PSCustomObject]@{
            DistinguishedName = $targetmatchedusers[$user.match].DistinguishedName
            SamAccountName = $targetmatchedusers[$user.match].SamAccountName
            Attribute = "DistinguishedName"
            NewValue = "OU=Leavers,OU=Users,OU=Quarantine,OU=Sync,DC=target,DC=company,DC=local"
            OldValue = $targetmatchedusers[$user.match].DistinguishedName
        }

    } # End If

} # End ForEach

# Compare users in Target with users in Source, if no match then add user to remove list
Write-Host "Checking if Target user matches with a Source user. Creating list of users who don't match and need to be removed."
ForEach($targetuser in $targetusers){

    # Is Target user in the Source users list
    $match = $null
    $match = [array]::IndexOf($sourceusers.EmployeeID, $targetuser.EmployeeID)

    If($match -eq -1){
		If($targetuser.'msDS-cloudExtensionAttribute10' -ne "1"){
			$removeusers += $targetuser
		} else {
			Write-Host "User Cloud Extension 10 is set to 1 so skipping user"
		}
    } # End If

} # End ForEach

# Find expired accounts
Write-Host "Checking for expired Target accounts that are not in leavers OU."
$expiredtargetusers = Search-ADAccount -AccountExpired | where {$_.DistinguishedName -notlike "*OU=Leavers,OU=Users,OU=Quarantine,OU=Sync,DC=target,DC=company,DC=local"}

ForEach($expacc in $expiredtargetusers){

    $expiredusers += [PSCustomObject]@{
        DistinguishedName = $expacc.DistinguishedName
        SamAccountName = $expacc.SamAccountName
        Attribute = "Enabled"
        NewValue = $false
        OldValue = $true
    }

} # End ForEach

# Find inactive accounts


# Process user updates
If($updateusers){

    Write-Host "Processing required updates"
    # Update Users Data
    $updatedatalogname = "Update-Data-" + $logname
    $path = $folder + $updatedatalogname
    $updateusers | Export-Csv -Path $path -Append -NoClobber -NoTypeInformation -Encoding UTF8 -Delimiter ";" -Force

    # Update Users
    $updatelogname = "Update-Results-" + $logname
    $path = $folder +  $updatelogname

    $failure = $false

    Try{

        $updateresult = Update-TargetUser -Data $updateusers -ReportOnly $false -Verbose
        $updateresult | Export-Csv -Path $path -Append -NoClobber -NoTypeInformation -Encoding UTF8 -Delimiter ";" -Force
    
    } Catch {

        $failure = $true
        Write-Warning $error[0].FullyQualifiedErrorId   

    } Finally {

        If($failure){
            $message = $error[0].FullyQualifiedErrorId  
            $subject = "Error in Sync Script"
            Send-Email -Message $Message -Subject $subject
        } # End If

    } # End Try/Catch/Finally

    $send = $false
    $subject = "ADSync - Error in Update Users Module"
    $message = "There was an error processing the following Updates:`r`n"

    ForEach($result in $updateresult){

        If($result.Success -eq $false){
            $send = $true 
            $message = $message + "$($result.DistinguishedName) - $($result.Success) - $($result.Result)`r`n"
        } # End If

    } # End ForEach

    If($send){
        Send-Email -Message $message -Subject $subject
    } # End If

} Else {

    Write-Host "No updates to process."

} # End If/Else

# Process user additions 
If($addusers){

    $adddatalogname = "Add-Data-" + $logname
    $path = $folder +  $adddatalogname
    $addusers | Export-Csv -Path $path -Append -NoClobber -NoTypeInformation -Encoding UTF8 -Delimiter ";" -Force

    $addlogname = "Add-Results-" + $logname
    $path = $folder +  $addlogname

    $failure = $false

    Try{

        $addresults = Add-TargetUser -Data $addusers -ReportOnly $false -Verbose
        $addresults | Export-Csv -Path $path -Append -NoClobber -NoTypeInformation -Encoding UTF8 -Delimiter ";" -Force
    
    } Catch {

        $failure = $true
        Write-Warning $error[0].FullyQualifiedErrorId   

    } Finally {

        If($failure){
            
            $message = $error[0].FullyQualifiedErrorId  
            $subject = "Error in Sync Script"
            Send-Email -Message $Message -Subject $subject

        } # End If

    } # End Try/Catch/Finally

    $send = $false
    $subject = "ADSync - Error in Add Users Module"
    $message = "There was an error processing the following new accounts:`r`n"

    ForEach($result in $addresults){

        If($result.Success -eq $false){

            $send = $true
            $message = $message + "$result.SamAccountName - $result.Success - $result.Result`r`n"

        } # End If

    } # End ForEach

    If($send){

        Send-Email -Message $message -Subject $subject

    } # End If

} Else {

    Write-Host "No new users to create."

} # End If/Else

# Process user removals
If($removeusers){

    $removedatalogname = "Remove-Data-" + $logname
    $path = $folder +  $removedatalogname
    $removeusers | Export-Csv -Path $path -Append -NoClobber -NoTypeInformation -Encoding UTF8 -Delimiter ";" -Force

    $removelogname = "Remove-Results-" + $logname
    $path = $folder + $removelogname

    $failure = $false

    Try{

        $removeresults = Remove-TargetUser -Data $removeusers -ReportOnly $false -Verbose 
        $removeresults | Export-Csv -Path $path -Append -NoClobber -NoTypeInformation -Encoding UTF8 -Delimiter ";" -Force

    } Catch {

        $failure = $true
        Write-Warning $error[0].FullyQualifiedErrorId   

    } Finally {

        If($failure){
            $message = $error[0].FullyQualifiedErrorId  
            $subject = "Error in Sync Script"
            Send-Email -Message $Message -Subject $subject
        } # End If

    } # End Try/Catch/Finally

    $send = $false
    $subject = "ADSync - Error in Remove Users Module"
    $message = "There was an error processing the following Removals:`r`n"

    ForEach($result in $removeresults){

        If($result.Success -eq $false){
            $send = $true
            $message = $message + "$result.SamAccountName - $result.Success - $result.Result`r`n"
        } # End If

    } # End ForEach

    If($send){

        Send-Email -Message $message -Subject $subject

    } # End If

} Else {

    Write-Host "No users to remove."

} # End If/Else

# Process expired users
If($expiredusers){
} Else {

    Write-Host "No expired users to process."

} # End If/Else

# Process inactive users
If($inactiveusers){
} Else {

    Write-Host "No inactive users to process."

} # End If/Else

Stop-Transcript
