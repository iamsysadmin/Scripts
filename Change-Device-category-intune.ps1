
# Change single device category script
# author: Remy Kuster
# website: www.iamsysadmin.eu

# Thanks to: https://jannikreinhard.com/2023/02/12/how-to-create-powershell-script-to-automate-tasks-in-intune/
# Thanks to: https://www.reddit.com/r/PowerShell/comments/15loa5f/mg_graph_device_category/
# Thanks to: https://github.com/JayRHa/Intune-Scripts/blob/main/Change-DeviceCategory/Change-DeviceCategorySingle.ps1

# Original source used: https://github.com/JayRHa/Intune-Scripts/blob/main/Change-DeviceCategory/Change-DeviceCategorySingle.ps1:

# Changes made:

# Find intune device by entering devicename and return device ID.
# Find categories based on name and return category ID.
# Check if device exists if not loop enter devicename.
# Check if category exists if not loop enter category.
# Check if category is set after script runs.
# Error handeling in function: Change-DeviceCategory
# Output changes

$ErrorActionPreference="silentlycontinue"

# First install PowerShell module Microsoft.Graph.Intune if not detected

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

    Connect-MsGraph -Quiet -ErrorAction Stop
}
Catch {
    Write-Host "An error occurred:"
    Write-Host $_
    Write-host "Script wil exit!"
    pause
}

$ConnectMsGraph = Connect-MsGraph

# Color functions to give Write-Output color

function Green
{
    process { Write-Host $_ -ForegroundColor Green }
}

function Red
{
    process { Write-Host $_ -ForegroundColor Red }
}

function Yellow
{
    process { Write-Host $_ -ForegroundColor Yellow }
}

# Function to change the device category, with error handeling

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

   write-host User $ConnectMsGraph.UPN is not authorized to perform this operation on device: $DeviceName! -ForegroundColor Red
   write-host Please check the permissions of the account and try again. -ForegroundColor Red
   $Error.Clear()
   
   }

} 

# Check if devicename exists if not loop to enter devicename again.

do{
   $DeviceName = Read-Host -Prompt 'Enter device name' 
   $DeviceExists = ((Invoke-MSGraphRequest -HttpMethod GET -Url 'deviceManagement/managedDevices').value | Where-Object DeviceName -EQ "$DeviceName")
   
   if (-not($DeviceExists).deviceName -eq $DeviceName)

   {
   Write-Host "Device: $DeviceName doesn't exist, please enter a correct device name" -ForegroundColor Red
   }

   else

   {
   Write-Host "Device: $DeviceName exists, continue script" -ForegroundColor Green


# Get the device ID

$DeviceID = ((Invoke-MSGraphRequest -HttpMethod GET -Url 'deviceManagement/managedDevices').value | Where-Object DeviceName -EQ "$DeviceName" | Select-Object Id).Id  

#Get the currently assigned category
 
$DeviceCategoryCurrent = ((Invoke-MSGraphRequest -HttpMethod GET -Url 'deviceManagement/managedDevices').value | Where-Object DeviceName -EQ "$DeviceName" | Select-Object DeviceCategoryDisplayName).DeviceCategoryDisplayName 

# Get the categories that are available to choose from and show them

$Categories = ((Invoke-MSGraphRequest -HttpMethod GET -Url 'deviceManagement/deviceCategories').value | Select-Object DisplayName).DisplayName


Write-Host -ForegroundColor Yellow "-----------------------------------"
Write-Host -ForegroundColor Yellow "|      Available Categories       |"
Write-Host -ForegroundColor Yellow "-----------------------------------"
Write-Output $Categories | Yellow
Write-Host

#Check if there is a category already assigned to the device

if ($DeviceCategoryCurrent -notcontains "Unknown") 

{ 

Write-Host -ForegroundColor Yellow "------------------------------------------"
Write-Host -ForegroundColor Yellow "|      Currently assigned category:      |"
Write-Host -ForegroundColor Yellow "------------------------------------------"
Write-Output $DeviceCategoryCurrent | Yellow
Write-Host

$PromptMessage = "Do you want to change the currently assigned category of the device? (Y/N)" } 

else 

{

Write-Host -ForegroundColor Yellow "-------------------------------"
Write-Host -ForegroundColor Yellow "|      Current category:      |"
Write-Host -ForegroundColor Yellow "-------------------------------"
Write-Host No category assigned
Write-Host


$PromptMessage = "Do you want to assign a category to the device ? (Y/N)"}


$AskingForChange = Read-Host -Prompt $PromptMessage 

if ($AskingForChange -eq "Y") 

{ 

# Check if category exists if not loop to enter category again.

do{
   $NewCategory = Read-Host -Prompt "Enter the category to assign to the device"

   $CategoryExists = ((Invoke-MSGraphRequest -HttpMethod GET -Url 'deviceManagement/deviceCategories').value |  Where-Object DisplayName -EQ "$NewCategory")
   
   if (-not($CategoryExists).displayName -eq $NewCategory)

   {
   Write-Host "Category: $NewCategory doesn't exist, please enter an available category" -ForegroundColor Red 
   }

   else

   {
   Write-Host "Category: $NewCategory exists, continue changing category on device" -ForegroundColor Green}}

   Until(($CategoryExists).displayName -like $NewCategory)
   
# Get the category ID

$NewCategoryID = ((Invoke-MSGraphRequest -HttpMethod GET -Url 'deviceManagement/deviceCategories').value |  Where-Object DisplayName -EQ "$NewCategory" | Select-Object ID).ID 

# Run the function to add or change the category

Change-DeviceCategory -DeviceID $DeviceID -NewCategoryID $NewCategoryID


# Check if the assignment of the new category is completed

do {

$DeviceCategoryCurrent = ((Invoke-MSGraphRequest -HttpMethod GET -Url 'deviceManagement/managedDevices').value | Where-Object DeviceName -EQ "$DeviceName" | Select-Object DeviceCategoryDisplayName).DeviceCategoryDisplayName

Write-Host Please wait! -ForegroundColor Yellow

Start-Sleep -Seconds 10

} until ($DeviceCategoryCurrent-like $NewCategory)

Write-Host Category of $DeviceName is changed to $NewCategory -ForegroundColor Green

pause

} 


else 

{ Write-Host "The category on device $DeviceName has not been changed" -ForegroundColor Red

pause


}

   
   }
}

Until(($DeviceExists).deviceName -like $DeviceName)
