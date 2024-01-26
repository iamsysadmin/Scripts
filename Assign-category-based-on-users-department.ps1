# Change assign device categorie gto devices from dynamic user group (department group in my case)
# author: Remy Kuster
# website: www.iamsysadmin.eu
# Version: 1.0

# This script allows you to use a dynamic user group and take the members UPN to compair it with intune managed devices and the assigned upn
# and then auto assign a device category to the devices of the users of the department. In my case We had a dynamic user group of a
# specific department and we wanted to automaticly assign the category of that department to the devices these users were using.

Set-ExecutionPolicy bypass -scope CurrentUser

Import-Module Microsoft.Graph.Intune

Connect-MSGraph

$ErrorActionPreference="silentlycontinue" # If you don't want the errors to be supressed change this into Continue, stop or Inquire

$NewCategoryID = "b561e58c-7dfe-4543-a654-8171d277ba63" #  enter the CategoryID you can get the CategoryID by running the cmdlet: Get-IntuneDeviceCategory

$EntraIDGroupID = "b561e58c-7dfe-4543-a654-8171d277ba63" # dccn group:  b561e58c-7dfe-4543-a654-8171d277ba63 enter the EntraID dynamic group ID you want to use the members of


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

   write-host User $ConnectMsGraph.UPN is not authorized to perform this operation -ForegroundColor Red
   write-host Please check the permissions of the account and try again. -ForegroundColor Red
   $Error.Clear()
   pause
   exit
   
   }

} 


$EmployeesUPN = Get-AzureADGroupMember -ObjectId $EntraIDGroupID -All $true | Select-Object -Property UserPrincipalName 

ForEach ($array in $EmployeesUPN){

$out1 = Get-IntuneManagedDevice | Where-Object UserPrincipalName -eq $array.UserPrincipalName | Select-Object -Property DeviceName,ID

write-host Collected UPNs: $out1

# Run the function to add or change the category

Change-DeviceCategory -DeviceID ($out1).ID -NewCategoryID $NewCategoryID

}
