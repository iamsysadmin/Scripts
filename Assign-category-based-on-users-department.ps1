# Change assign device category to macOS or Windows devices based on User department
# author: Remy Kuster
# website: www.iamsysadmin.eu
# Version: 2.0
# Added parameters so script doesn't have to be changed every time
# Changed the flow of the scipt to be more efficient: First check Intune managed devices then the assigned primary user and the department of the user.

# This script allows you to check the intune managed devices and the primary users upn. 
# Then check if the user is a member of the department and assign the correct device (department) category to the device.
# Usage: Assign-device-category-based-on-users-department.ps1 -NewCategoryName [Value] -OperatingSystem (macOS or Windows) -$Department [Value] (users department)

Param(
     [Parameter(Mandatory)]
     [string]$NewCategoryName,

     [Parameter(Mandatory)]
     [string]$OperatingSystem,

     [Parameter(Mandatory)]
     [string]$Department
 )

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

$NewCategoryID = (Get-IntuneDeviceCategory | Where-Object DisplayName -EQ "$NewCategoryName" | Select-Object ID).ID 

$EmployeesUPN = (Get-IntuneManagedDevice | Where-Object OperatingSystem -EQ $OperatingSystem | Select-Object -Property DeviceName,ID,UserPrincipalName)

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

# Check for every user based on the UPN if there is a Intune managed macOS device assigned to the user, if so assign the new category to the device

ForEach ($array in $EmployeesUPN)

{

$UPN = $array.userPrincipalName


# Run the function to add or change the category IF the user is member of the department.

if ((Invoke-MSGraphRequest -Url "https://graph.microsoft.com/beta/users/$UPN" -HttpMethod Get | Select-Object Department) -match $Department) 

{  

Write-Host User $UPN is member of department $Department -ForegroundColor Green 

# Check if the new category isn't already assigned to the device

$DeviceCategoryCurrent = ( Get-IntuneManagedDevice | Where-Object DeviceName -EQ $array.deviceName | Select-Object DeviceCategoryDisplayName).DeviceCategoryDisplayName

if ($NewCategoryName -eq "$DeviceCategoryCurrent") 

{
  write-host Category $NewCategoryName is already assigned to device: $array.deviceName -ForegroundColor Red
  
}

else

{

Write-host Category $NewCategoryName is NOT assigned to device: $array.deviceName -ForegroundColor Yellow
Write-host Adding category $NewCategoryName to device: $array.deviceName -ForegroundColor Yellow

Change-DeviceCategory -DeviceID ($array).ID -NewCategoryID $NewCategoryID

# Check if the assignment of the new category is completed

do {

$DeviceCategoryCurrent = ( Get-IntuneManagedDevice | Where-Object DeviceName -EQ $array.deviceName | Select-Object DeviceCategoryDisplayName).DeviceCategoryDisplayName

Write-Host Please wait! -ForegroundColor Yellow

Start-Sleep -Seconds 10

} 

until ($DeviceCategoryCurrent-like $NewCategoryName)

Write-Host Category of $array.deviceName is changed to $NewCategoryName -ForegroundColor Green

}

}

else

{

Write-Host User $UPN is NOT member of department $Department so category: $NewCategoryName not assigned to Device: $array.deviceName -ForegroundColor Red

}

}
