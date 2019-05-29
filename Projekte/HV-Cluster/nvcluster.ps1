# Vorbereitung für ein Cluster aus 2 Hyper-V VMs mit Namen nhv01 und nHV02

# Virtuelle Switche erstellen
function SwitchTest ($SwitchName = "StandardSwitch") {

# Prüfen, ob ein Privater Switch namens "$SwitchName" schon vorhanden ist und der Variablen den Wert True oder False geben
$VirtualSwitchExists = ((Get-VMSwitch | where {$_.name -eq $SwitchName -and $_.SwitchType -eq "Private"}).count -ne 0)

# Falls kein Switch vorhanden ist wird er angelegt
if ($VirtualSwitchExists -like "False")
  {
   New-VMSwitch -SwitchName $SwitchName -SwitchType Private
   write-host "Privater Switch $SwitchName wurde erstellt"
  }
else
  {
    write-host "Privater Switch $SwitchName ist schon vorhanden"
  }

}

SwitchTest nvstor1
SwitchTest nvstor2
SwitchTest nvCluster

# zusatzliche NICs an die VMs hängen
Add-VMNetworkAdapter -VMName nhv01 -SwitchName "nvstor1"
Add-VMNetworkAdapter -VMName nhv01 -SwitchName "nvstor2"
Add-VMNetworkAdapter -VMName nhv01 -SwitchName "nvcluster"
Add-VMNetworkAdapter -VMName nhv02 -SwitchName "nvstor1"
Add-VMNetworkAdapter -VMName nhv02 -SwitchName "nvstor2"
Add-VMNetworkAdapter -VMName nhv02 -SwitchName "nvcluster"
Add-VMNetworkAdapter -VMName App02 -SwitchName "nvstor1"
Add-VMNetworkAdapter -VMName App02 -SwitchName "nvstor2"


# MACAddressSpoofing einschalten
Set-VMNetworkAdapter -VMName nhv01 -MacAddressSpoofing on
Set-VMNetworkAdapter -VMName nhv02 -MacAddressSpoofing on

# Virtualisierung für VM konfigurieren
Set-VMProcessor -VMName nhv01 -ExposeVirtualizationExtensions $true -Count 2
Set-VMProcessor -VMName nhv02 -ExposeVirtualizationExtensions $true -Count 2

# 4GB statischen Arbeitsspeicher vergeben
Set-VMMemory -VMName nhv01 -DynamicMemoryEnabled $false -StartupBytes 4GB
Set-VMMemory -VMName nhv02 -DynamicMemoryEnabled $false -StartupBytes 4GB

#VMs starten
Start-VM -Name nhv01
Start-VM -Name nhv02

## Zuordnung der Switche zu den NICs in der VM $vmName prüfen und umbennen
function NicSwitch ($vmName) {
  $netnames = (Get-VMNetworkAdapter -VMName $vmName).SwitchName
  foreach ($netname in $netnames) {
  $adapterID =(Get-VMNetworkAdapter -VMName $vmName | where SwitchName -EQ $netname).AdapterId
  Get-VMNetworkAdapter -VMName $vmName | where Switchname -EQ $netname | Disconnect-VMNetworkAdapter
  Invoke-Command -VMName $vmName -Credential $credential {get-netadapter | where status -EQ Disconnected | Rename-NetAdapter -NewName $Using:netname}
  Get-VMNetworkAdapter -VMName $vmName | where AdapterId -eq $adapterID | Connect-VMNetworkAdapter -SwitchName $netname
  }
}

# Zugagngsdaten für NHV01 und NHV02 als Workgroup Mitglieder
$username = "Administrator" 
$password = 'Pa$$w0rd' | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username,$password)

## Zuordnung der Switche zu den NICs in der VM nhv01 prüfen und umbennen
NicSwitch -vmName nhv01

Enter-PSSession -VMName nhv01 -Credential $credential
# Per Powershell Direct die IP-Adressen auf NHV01 setzen und Domäne hinzufügen
$Netnames = @("corpnet","nvstor1","nvstor2","nvcluster")
foreach ($Netname in $Netnames) {
Set-NetIPInterface -InterfaceAlias $Netname -Dhcp Disabled
}
New-NetIPAddress -InterfaceAlias corpnet -IPAddress 172.16.0.31 -DefaultGateway 172.16.0.1 -PrefixLength 24
Set-DNSClientServerAddress -InterfaceAlias corpnet -ServerAddresses 172.16.0.11
New-NetIPAddress -InterfaceAlias nvcluster -IPAddress 10.10.0.31 -PrefixLength 24
New-NetIPAddress -InterfaceAlias nvstor1 -IPAddress 10.10.1.31 -PrefixLength 24
New-NetIPAddress -InterfaceAlias nvstor2 -IPAddress 10.10.2.31 -PrefixLength 24

$domain = "corp.howilab.local"
$username = "$domain\Administrator"
$password = 'Pa$$w0rd' | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username,$password)
Add-Computer -DomainName $domain -Credential $credential
Rename-computer nhv01
Exit-PSSession
Restart-VM -Name nhv01 -force

## Zuordnung der Switche zu den NICs in der VM nhv02 prüfen und umbennen
NicSwitch -vmName nhv02

Enter-PSSession -VMName nhv02 -Credential $credential
# Per Powershell Direct die IP-Adressen auf NHV02 setzen und Domäne hinzufügen
$Netnames = @("corpnet","nvstor1","nvstor2","nvcluster")
foreach ($Netname in $Netnames) {
Set-NetIPInterface -InterfaceAlias $Netname -Dhcp Disabled
}
New-NetIPAddress -InterfaceAlias corpnet -IPAddress 172.16.0.32 -DefaultGateway 172.16.0.1 -PrefixLength 24
Set-DNSClientServerAddress -InterfaceAlias corpnet -ServerAddresses 172.16.0.11
New-NetIPAddress -InterfaceAlias nvcluster -IPAddress 10.10.0.32 -PrefixLength 24
New-NetIPAddress -InterfaceAlias nvstor1 -IPAddress 10.10.1.32 -PrefixLength 24
New-NetIPAddress -InterfaceAlias nvstor2 -IPAddress 10.10.2.32 -PrefixLength 24

$domain = "corp.howilab.local"
$username = "$domain\Administrator" 
$password = 'Pa$$w0rd' | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username,$password)
Add-Computer -DomainName $domain -Credential $credential
Rename-computer nhv02
Exit-PSSession
Restart-VM -Name nhv02 -force

## Rollen und Feature auf nhv01 und nhv02 installieren
# Zugagngsdaten für NHV01 und NHV02 als Domain Member
$domain = "corp.howilab.local"
$username = "$domain\Administrator"
$password = 'Pa$$w0rd' | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username,$password)

Enter-PSSession -VMName nhv01 -Credential $credential
Install-WindowsFeature -Name Hyper-V,Failover-Clustering,Multipath-IO -IncludeAllSubFeature -IncludeManagementTools -Restart

Enter-PSSession -VMName nhv02 -Credential $credential
Install-WindowsFeature -Name Hyper-V,Failover-Clustering,Multipath-IO -IncludeAllSubFeature -IncludeManagementTools -Restart

## Zuordnung der Switche zu den NICs in der VM App02 prüfen und umbennen
NicSwitch -vmName App02

## iscsi Target auf App02 installieren
Enter-PSSession -VMName App02 -Credential $credential

New-NetIPAddress -InterfaceAlias nvstor1 -IPAddress 10.10.1.22 -PrefixLength 24
New-NetIPAddress -InterfaceAlias nvstor2 -IPAddress 10.10.2.22 -PrefixLength 24
Install-WindowsFeature -Name FS-iSCSITarget-Server 
New-IscsiVirtualDisk -Path c:\iscsiVirtualDisks\Quorum.vhdx -SizeBytes 1GB
New-IscsiVirtualDisk -Path c:\iscsiVirtualDisks\CSVData.vhdx -SizeBytes 40GB
New-IscsiServerTarget -TargetName nhvHosts
Set-IscsiServerTarget -TargetName nhvHosts -InitiatorIds IPAddress:10.10.1.31,IPAddress:10.10.2.31,IPAddress:10.10.1.32,IPAddress:10.10.2.32
Add-IscsiVirtualDiskTargetMapping -Path c:\iscsiVirtualDisks\Quorum.vhdx -TargetName nhvHosts
Add-IscsiVirtualDiskTargetMapping -Path c:\iscsiVirtualDisks\CSVData.vhdx -TargetName nhvHosts
Exit-PSSession

# Konfigurieren des iSCSI Initiators mit MPIO auf nhv01
Enter-PSSession -VMName nhv01 -Credential $credential
Set-Service -Name msiscsi -StartupType Automatic
Start-Service msiscsi
Get-NetFirewallServiceFilter -Service msiscsi | Enable-NetFirewallRule
Enable-MSDSMAutomaticClaim -BusType iSCSI
New-IscsiTargetPortal –TargetPortalAddress 10.10.1.22
New-IscsiTargetPortal -TargetPortalAddress 10.10.2.22
Get-IscsiTarget | Connect-IscsiTarget  -IsPersistent $True –IsMultipathEnabled $True –InitiatorPortalAddress 10.10.1.31
Get-IscsiTarget | Connect-IscsiTarget  -IsPersistent $True –IsMultipathEnabled $True –InitiatorPortalAddress 10.10.2.31

get-disk | where Size -EQ 1GB | Initialize-Disk -PartitionStyle MBR
get-disk | where Size -EQ 40GB | Initialize-Disk -PartitionStyle MBR
get-disk | where Size -EQ 1GB | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Quorum"
get-disk | where Size -EQ 40GB | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "CSVData"

Exit-PSSession

# Konfigurieren des iSCSI Initiators mit MPIO auf nhv02
Enter-PSSession -VMName nhv02 -Credential $credential
Set-Service -Name msiscsi -StartupType Automatic
Start-Service msiscsi
Get-NetFirewallServiceFilter -Service msiscsi | Enable-NetFirewallRule
Enable-MSDSMAutomaticClaim -BusType iSCSI
New-IscsiTargetPortal –TargetPortalAddress 10.10.1.22
New-IscsiTargetPortal -TargetPortalAddress 10.10.2.22
Get-IscsiTarget | Connect-IscsiTarget  -IsPersistent $True –IsMultipathEnabled $True –InitiatorPortalAddress 10.10.1.32
Get-IscsiTarget | Connect-IscsiTarget  -IsPersistent $True –IsMultipathEnabled $True –InitiatorPortalAddress 10.10.2.32

get-disk | where Size -EQ 1GB | set-disk -IsOffline:$false
get-disk | where Size -EQ 40GB | set-disk -IsOffline:$false

Exit-PSSession

## Cluster erstellen auf NHV01
Enter-PSSession -VMName nhv01 -Credential $credential
# Validierungstest 
Test-Cluster –Node NHV01,NHV02
# Cluster erstellen
New-Cluster –Name HVCluster –Node NHV01,NHV02 –StaticAddress 172.16.0.40
