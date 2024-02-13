# Change assign device category to macOS devices based on User department
# author: Remy Kuster
# website: www.iamsysadmin.eu
# Version: 1.0

# This script allows you to use a EntraID user group and take the members UPN to compare it with intune managed devices and the assigned upn.
# Then the script assigns the new device category to the devices of the users of the department if the user has got an Intune managed device. 
# In my case We had a dynamic user group of a specific department and we wanted to automatically assign the category of that department to the macOS devices of these users.

$moduleName = "Microsoft.Graph.Intune"
if (-not (Get-Module -Name $moduleName)) {
    try {
        Write-Host Module $moduleName not detected starting installing module $moduleName
        Install-Module $moduleName -Scope CurrentUser -Force
        Write-Host Module $moduleName installed
    }catch {
        Write-Error "Failed to install $moduleName"
        Write-host "Script wil exit!"
        pause
        Exit
    }
}

else

{
Write-Host Module $moduleName detected no install needed

}


# Authenticate 

Try {

    Connect-MsGraph -Quiet -ErrorAction Continue
}
Catch {
    Write-Host "An error occurred:" -ForegroundColor Red
    Write-Host $_ -ForegroundColor Red
    pause
    exit
}

$ConnectMsGraph = Connect-MsGraph

$ErrorActionPreference= "continue" # If you don't want the errors to be supressed change this into Continue, stop or Inquire

$NewCategoryName = "IT-Services" # Enter the Device Category Name you want to set.

$EntraIDGroupName = "F-AZ-Intune-Information&Library-Services-Employees-DU" # Enter the EntraID dynamic user groupname based on department

$NewCategoryID = (Get-IntuneDeviceCategory | Where-Object DisplayName -EQ "$NewCategoryName" | Select-Object ID).ID 

$EntraIDGroupID = (Get-AADGroup | Get-MSGraphAllPages | Where-Object Displayname -EQ $EntraIDGroupName).ID

$EmployeesUPN = Get-AADGroupMember -groupId $EntraIDGroupID | Get-MSGraphAllPages | Select-Object UserPrincipalName 

$OperatingSystem = "macOS" # Enter the Operatingsystem the device must have can be macOS or Windows or Linux

function Change-DeviceCategory {
	param(
		[Parameter(Mandatory)]
		[string]$DeviceID,
		
		[Parameter(Mandatory)]
		[string]$NewCategoryID
	)

    $body = @{ "@odata.id" = "https://graph.microsoft.com/beta/deviceManagement/deviceCategories/$NewCategoryID" }
    Invoke-MSGraphRequest -HttpMethod PUT -Url "deviceManagement/managedDevices/$DeviceID/deviceCategory/`$ref" -Content $body

   if( $error[0].Exception -like "*User is not authorized to perform this operation*")

   {

   write-host User $ConnectMsGraph.UPN is not authorized to perform this operation! -ForegroundColor Red
   write-host Please check the permissions of the account and try again. -ForegroundColor Red
   $Error.Clear()
   
   }

} 

# Check for every user based on theire UPN if there is a Intune managed macOS device assigned to the user, if so assign the new category to the device

ForEach ($array in $EmployeesUPN)

{

$out1 = Get-IntuneManagedDevice | Where-Object UserPrincipalName -eq $array.userPrincipalName | Select-Object -Property DeviceName,ID,OperatingSystem


# Run the function to add or change the category IF a managed device is found for the User AND if OS is macOS

if (($out1.id) -ne $null -and ($out1.operatingSystem) -match $OperatingSystem) 

{  

Write-Host Intune managed macOS device found: $out1.deviceName User: $array.userPrincipalName -ForegroundColor Green 

# Check if the new category isn't already assigned to the device

$DeviceCategoryCurrent = ( Get-IntuneManagedDevice | Where-Object DeviceName -EQ $out1.deviceName | Select-Object DeviceCategoryDisplayName).DeviceCategoryDisplayName

if ($NewCategoryName -eq "$DeviceCategoryCurrent") 

{
  write-host Category $NewCategoryName is already assigned to device: $out1.deviceName -ForegroundColor Red
  
}

else

{

Write-host Category $NewCategoryName is NOT assigned to device: $out1.deviceName -ForegroundColor Yellow

Change-DeviceCategory -DeviceID ($out1).ID -NewCategoryID $NewCategoryID

# Check if the assignment of the new category is completed

do {

$DeviceCategoryCurrent = ( Get-IntuneManagedDevice | Where-Object DeviceName -EQ $out1.deviceName | Select-Object DeviceCategoryDisplayName).DeviceCategoryDisplayName

Write-Host Please wait! -ForegroundColor Yellow

Start-Sleep -Seconds 10

} 

until ($DeviceCategoryCurrent-like $NewCategoryName)

Write-Host Category of $out1.deviceName is changed to $NewCategoryName -ForegroundColor Green

}

}

}
