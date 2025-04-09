# Assumes you have a working VCF environment and a VM template to clone

$vcServer = "vcenter-vcf01.home.virtualelephant.com"
$vcUsername = "administrator@vsphere.local"
$vcPassword = ""

Connect-VIServer -Server $vcServer -User $vcUsername -Password $vcPassword

# Variables
$templateName = "centos-stream-9-template"
$destinationFolder = "OpenShift"
$datastore = "ve-m01-cluster-001-vsan"
$clusterName = "ve-m01-cluster-001"
$networkAdapterName = "Network adapter 1"
$newPortGroup = "k8s-openshift-1"
$contentLibraryName = "LocalContentLibrary" # Change this to match your actual Content Library
$isoName = "openshift-installer.iso"

$template = Get-VM -Name $templateName -ErrorAction Stop
$cluster = Get-Cluster -Name $clusterName -ErrorAction Stop

Write-Host "VM Template: $template"
Write-Host "Cluster: $cluster"

# Fetch the ISO from the Content Library
$library = Get-ContentLibrary -Name $contentLibraryName
$isoItem = Get-ContentLibraryItem -ContentLibrary $library | Where-Object { $_.Name -eq $isoName }

if (-not $isoItem) {
    Write-Error "ISO '$isoName' not found in Content Library '$contentLibraryName'. Exiting script."
    return
}


# Clone the template for masters
0..2 | ForEach-Object {
    $vmName = "master$($_)"
    
    if (Get-VM -Name $vmName -ErrorAction SilentlyContinue) {
        Write-Host "VM '$vmName' already exists. Skipping..."
        return
    }

    $vm = New-VM -Name $vmName -VM $template -Datastore $datastore -Location $destinationFolder -ResourcePool $cluster

    $networkAdapter = Get-NetworkAdapter -VM $vm -Name $networkAdapterName
    Set-NetworkAdapter -NetworkAdapter $networkAdapter -NetworkName $newPortGroup -Confirm:$false

    # Set disk.EnableUUID = TRUE
    New-AdvancedSetting -Entity $vm -Name "disk.EnableUUID" -Value "TRUE" -Confirm:$false

    # Add and mount ISO from content library
    $cdDrive = Get-CDDrive -VM $vm | Where-Object { $_.Name -eq "CD/DVD drive 1" }
    if (-not $cdDrive) {
        $cdDrive = New-CDDrive -VM $vm -StartConnected $true -Confirm:$false
    }

    Set-CDDrive -CDDrive $cdDrive -ContentLibraryIso -ContentLibraryItem $isoItem -StartConnected $true -Confirm:$false

    Write-Host "Cloned VM: $vmName with disk.EnableUUID=TRUE and ISO mounted"}

# Clone the template for workers
0..4 | ForEach-Object {
    $vmName = "worker$($_)"
    
    if (Get-VM -Name $vmName -ErrorAction SilentlyContinue) {
        Write-Host "VM '$vmName' already exists. Skipping..."
        return
    }

    $vm = New-VM -Name $vmName -VM $template -Datastore $datastore -Location $destinationFolder -ResourcePool $cluster

    $networkAdapter = Get-NetworkAdapter -VM $vm -Name $networkAdapterName
    Set-NetworkAdapter -NetworkAdapter $networkAdapter -NetworkName $newPortGroup -Confirm:$false

    # Set disk.EnableUUID = TRUE
    New-AdvancedSetting -Entity $vm -Name "disk.EnableUUID" -Value "TRUE" -Confirm:$false

    # Add and mount ISO from content library
    $cdDrive = Get-CDDrive -VM $vm | Where-Object { $_.Name -eq "CD/DVD drive 1" }
    if (-not $cdDrive) {
        $cdDrive = New-CDDrive -VM $vm -StartConnected $true -Confirm:$false
    }

    Set-CDDrive -CDDrive $cdDrive -ContentLibraryIso -ContentLibraryItem $isoItem -StartConnected $true -Confirm:$false

    Write-Host "Cloned VM: $vmName with disk.EnableUUID=TRUE and ISO mounted"
}

# Disconnect from vCenter
Disconnect-VIServer -Server $vcServer -Confirm:$false