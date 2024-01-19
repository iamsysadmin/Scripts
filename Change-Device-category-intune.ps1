
# Change single device category script
# auther: Remy Kuster
# website: www.iamsysadmin.eu

# Thanks to: https://jannikreinhard.com/2023/02/12/how-to-create-powershell-script-to-automate-tasks-in-intune/
# Thanks to: https://www.reddit.com/r/PowerShell/comments/15loa5f/mg_graph_device_category/
# Thanks to: https://github.com/JayRHa/Intune-Scripts/blob/main/Change-DeviceCategory/Change-DeviceCategorySingle.ps1

# Origional source used: https://github.com/JayRHa/Intune-Scripts/blob/main/Change-DeviceCategory/Change-DeviceCategorySingle.ps1:

# Changes made:

# Find intune device by entering device name and return device ID.
# Find categories based on name and return category ID.
# Check if device exists if not loop enter device name.
# Check if category is set after scipt runs.
# Output changes

# First install PowerShell module Microsoft.Graph.Intune if not detected

$moduleName = "Microsoft.Graph.Intune"
if (-not (Get-Module -Name $moduleName)) {
    try {
        Write-Host Module $moduleName not detected starting installing module $moduleName
        Install-Module $moduleName -Scope CurrentUser -Force
        Write-Host Module $moduleName installed
    }catch {
        Write-Error "Failed to install $moduleName"
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
}


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




function Change-DeviceCategory {
	param(
		[Parameter(Mandatory)]
		[string]$DeviceID,
		
		[Parameter(Mandatory)]
		[string]$NewCategoryID
	)

    $body = @{ "@odata.id" = "https://graph.microsoft.com/beta/deviceManagement/deviceCategories/$NewCategoryID" }
    Invoke-MSGraphRequest -HttpMethod PUT -Url "deviceManagement/managedDevices/$DeviceID/deviceCategory/`$ref" -Content $body

} 

#Check if devicename exists if not loop to enter devicename again.

do{
   $DeviceName = Read-Host -Prompt 'Enter device name' 
   $DeviceExists = ((Invoke-MSGraphRequest -HttpMethod GET -Url 'deviceManagement/managedDevices').value | Where-Object DeviceName -EQ "$DeviceName")
   
   if (-not($DeviceExists).deviceName -eq $DeviceName)

   {
   Write-Host "Device $DeviceName doesn't exist, please enter a correct device" 
   }

   else

   {
   Write-Host "Device $DeviceName exists, continue script"


#Get the device ID

$DeviceID = ((Invoke-MSGraphRequest -HttpMethod GET -Url 'deviceManagement/managedDevices').value | Where-Object DeviceName -EQ "$DeviceName" | Select-Object Id).Id  

#Get the currently assigned category
 
$DeviceCategoryCurrent = ((Invoke-MSGraphRequest -HttpMethod GET -Url 'deviceManagement/managedDevices').value | Where-Object DeviceName -EQ "$DeviceName" | Select-Object DeviceCategoryDisplayName).DeviceCategoryDisplayName 

#Get the categories that are available to choose from and show them

$Categories = ((Invoke-MSGraphRequest -HttpMethod GET -Url 'deviceManagement/deviceCategories').value | Select-Object DisplayName).DisplayName


Write-Host -ForegroundColor Yellow "-----------------------------------"
Write-Host -ForegroundColor Yellow "|      Available Categories       |"
Write-Host -ForegroundColor Yellow "-----------------------------------"
Write-Output $Categories | Yellow
Write-Host

#Check if there is a category already assigned to the device

if ($DeviceCategoryCurrent -notcontains "Unknown") 

{ 

Write-Host -ForegroundColor Yellow "-------------------------------"
Write-Host -ForegroundColor Yellow "|      Current category:      |"
Write-Host -ForegroundColor Yellow "-------------------------------"
Write-Output $DeviceCategoryCurrent | Yellow
Write-Host

$PromptMessage = "Do you want to change the current category of the device ? (Y/N)" } 

else 

{

Write-Host -ForegroundColor Yellow "-------------------------------"
Write-Host -ForegroundColor Yellow "|      Current category:      |"
Write-Host -ForegroundColor Yellow "-------------------------------"
Write-Host No category assigned
Write-Host


$PromptMessage = "Do you want to add a category to the device ? (Y/N)"}


$AskingForChange = Read-Host -Prompt $PromptMessage 

if ($AskingForChange -eq "Y") 

{Write-Host

$NewCategory = Read-Host -Prompt "Enter the category to assign to the device" 

$NewCategoryID = ((Invoke-MSGraphRequest -HttpMethod GET -Url 'deviceManagement/deviceCategories').value |  Where-Object DisplayName -EQ "$NewCategory" | Select-Object ID).ID 

Change-DeviceCategory -DeviceID $DeviceID -NewCategoryID $NewCategoryID

# Check if the assignment of the new category is completed

do {

$DeviceCategoryCurrent = ((Invoke-MSGraphRequest -HttpMethod GET -Url 'deviceManagement/managedDevices').value | Where-Object DeviceName -EQ "$DeviceName" | Select-Object DeviceCategoryDisplayName).DeviceCategoryDisplayName

Write-Host Please wait! -ForegroundColor Red

Start-Sleep -Seconds 10

} until ($DeviceCategoryCurrent-like $NewCategory)

Write-Host Category of $DeviceName is changed to $NewCategory -ForegroundColor Green

} 


else 

{ Write-Host "The category on device $DevicName has not been changed" -ForegroundColor Red}
   
   }
}

Until(($DeviceExists).deviceName -like $DeviceName)
