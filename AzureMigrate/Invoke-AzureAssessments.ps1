cd 'd:\Azure_Migrate'
Import-Module .\AzureMigrateAssessmentCreationUtility.psm1


Connect-AzAccount -Tenant '000000000000000000'

# Declare variables
$subscriptionId = "000000000000000000"
$resourceGroupName = "TMP_Company_AzMigrate"

#Query the name of your Azure Migrate project
Get-AzureMigrateAssessmentProject -subscriptionId $subscriptionId -resourceGroupName $resourceGroupName
$assessmentProjectName = "aerospace2793project"

#Create assessments

$assessment = Get-AzureMigrateAssessmentProject -subscriptionId $subscriptionId -resourceGroupName $resourceGroupName
$assessmentProjectName = $assessment.name

New-AssessmentCreation -subscriptionId $subscriptionID -resourceGroupName $resourceGroupName -assessmentProjectName $assessmentProjectName -discoverySource "Appliance"
