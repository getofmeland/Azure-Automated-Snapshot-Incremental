$connectionName = "AzureRunAsConnection"

try{

#Getting the service principal connection "AzureRunAsConnection"

$servicePrincipalConnection = Get-AutomationConnection -name $connectionName

"Logging into Azure..."

Add-AzAccount -ServicePrincipal -Tenant $servicePrincipalConnection.TenantID -ApplicationID $servicePrincipalConnection.ApplicationID -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint

}

catch{

if(!$servicePrincipalConnection){

$ErrorMessage = "Connection $connectionName not found."

throw $ErrorMessage

}else {

Write-Error -Message $_.Exception

throw $_.Exception

}

}

if($err) {

throw $err

}

# Get VMs with snapshot tag

$tagResList = Get-AzResource -TagName "Snapshot" -TagValue "True" | foreach {

Get-AzResource -ResourceId $_.resourceid

}

foreach($tagRes in $tagResList) {

if($tagRes.ResourceId -match "Microsoft.Compute")

{

$vmInfo = Get-AzVM -ResourceGroupName $tagRes.ResourceId.Split("//")[4] -Name $tagRes.ResourceId.Split("//")[8]


#Set local variables

$location = $vmInfo.Location

$resourceGroupName = $vmInfo.ResourceGroupName

#$timestamp = Get-Date -f MM-dd-yyyy_HH_mm_ss


#Snapshot name of OS data disk

$snapshotName = $vmInfo.Name + "-snap" #+ $timestamp

#Create snapshot configuration

$snapshot = New-AzSnapshotConfig -SourceUri $vmInfo.StorageProfile.OsDisk.ManagedDisk.Id -Location $location -CreateOption Copy -Incremental
#$snapshot = New-AzureRmSnapshotConfig -SourceUri $vmInfo.StorageProfile.OsDisk.ManagedDisk.Id -Location $location -CreateOption copy

#Take snapshot

New-AzSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName -Snapshot $snapshot
#New-AzureRmSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName

if($vmInfo.StorageProfile.DataDisks.Count -ge 1){

#Condition with more than one data disks

for($i=0; $i -le $vmInfo.StorageProfile.DataDisks.Count - 1; $i++){

#Snapshot name of OS data disk

$snapshotName = $vmInfo.StorageProfile.DataDisks[$i].Name + "-snap"

#Create snapshot configuration

$snapshot = New-AzSnapshotConfig -SourceUri $vmInfo.StorageProfile.DataDisks[$i].ManagedDisk.Id -Location $location -CreateOption Copy -Incremental
#$snapshot = New-AzureRmSnapshotConfig -SourceUri $vmInfo.StorageProfile.DataDisks[$i].ManagedDisk.Id -Location $location -CreateOption copy

#Take snapshot

New-AzSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName -Snapshot $snapshot
#New-AzureRmSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName

}

}

else{

Write-Host $vmInfo.Name + " doesn't have any additional data disk."

}

}

else{

$tagRes.ResourceId + " is not a compute instance"

}

}
