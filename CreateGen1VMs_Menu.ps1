# Virtuelle Gen1 Maschinen für howi-lab erstellen
# Es werden Basis vhds für Server 2012 R2, Server 2016, Windows 8.1 und Windows 10 verwendet
# Die einzelnen Maschinen der Testumgebung werden über MDT (LiteTouchMedia.iso) erstellt

# Als Admin gestartet?
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
If (!( $isAdmin )) {
    Write-Host "-- Starte neu als Administrator" -ForegroundColor Cyan ; Start-Sleep -Seconds 1
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs 
    exit
}

# Eingabe des Laufwerkbuchstabens ohne ":" und testen, ob es den Ordner VMs dort gibt
do {
 $drive = Read-Host "Auf welchem Laufwerk (c, d, e) liegen die Basis-Images?"
 $drivevms = $drive + ":\VMs"
 if (-not (Test-Path $drivevms))  {
    Write-Warning "Auf Laufwerk $drive wurden keine Basis-Images gefunden :-("}
} until  (Test-Path $drivevms)

# Einige Variablen
  $VMLocation = $drivevms + "\howi-lab"
  $unattendFile = $drivevms + "\unattend.xml"
  $VMIso = $drivevms + "\LiteTouchMedia.iso"
  $VMBaseDisk = $drivevms + "\howi-lab\Base\BaseServer2012.vhd"
  $VMBaseDisk16 = $drivevms + "\howi-lab\Base\BaseServer2016.vhd"
  $VMBaseDisk19 = $drivevms + "\howi-lab\Base\BaseServer2019.vhd"
  $VMBaseClient = $drivevms + "\howi-lab\Base\BaseW81.vhd"
  $VMBase10Client = $drivevms + "\howi-lab\Base\BaseW10.vhd"

# Virtuelle Switche erstellen
function SwitchTest ($SwitchName = "StandadrdSwitch") {

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

Switchtest Corpnet
Switchtest Inet

# Unattend.xml in die vhd kopieren - falls nicht schon im Image vorhanden ;-)
function injectunattend ($VMName, $imgPath) {
  $mountdir = "$VMLocation\$VMName\Virtual Hard Disks\Temp\mountdir"
  New-item -type directory -Path $mountdir -force
  Mount-WindowsImage -Path $mountdir -ImagePath $imgPath -Index 1
  Use-WindowsUnattend -Path $mountdir -UnattendPath $unattendFile
  New-item -type directory -Path "$mountdir\Windows\Panther" -force
  Copy-Item -Path $unattendFile -Destination "$mountdir\Windows\Panther\unattend.xml" -force
  Dismount-WindowsImage -Path $mountdir -Save
}
# Virtuelle Maschinen erstellen 
function BuildVM ($VmName, $VMMemory=2048MB, $VMDiskSize=0GB, $VMNetwork = "Corpnet", $SecondNetwork=$false, $OSBaseDisk) {

  New-VM -Name $VMName -BootDevice CD -MemoryStartupBytes $VMMemory -SwitchName $VMNetwork -Path $VMLocation -NoVHD
  $VHDPath = New-VHD -Path "$VMLocation\$VMName\Virtual Hard Disks\$VMName-Disk1.vhd" -ParentPath $OSBasedisk -SizeBytes $VMDiskSize
  # Falls noch keine Antwortdatei im Image vorhanden, die nächste Zeile entkommentieren!
  # injectunattend -VMname $VMName -imgPath $VHDPath.Path
  Add-VMHardDiskDrive -VMName $VMName -Path "$VMLocation\$VMName\Virtual Hard Disks\$VMName-Disk1.vhd"
  Set-VMDvdDrive -VMName $VMName -Path $VMIso
  Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false
  Set-VM -Name $VMName  -AutomaticStopAction ShutDown
  If ($SecondNetwork) {
    Add-VMNetworkAdapter -VMName $VMname -SwitchName "Inet"
  }
}

function Show-Menu
{
     param (
           [string]$Title = 'Erstelle folgende VM'
     )
     cls
     Write-Host "============== $Title ==============" -ForegroundColor Yellow
     Write-Host     
     Write-Host "Maschinen auf Basis Server 2012 R2" -ForegroundColor Green
     Write-Host "----------------------------------" -ForegroundColor Green
     Write-Host "1: DC01"
     Write-Host "2: App01"
     Write-Host "E: Edge01"
     Write-Host "I: Inet01"
     Write-Host
     Write-Host "Maschinen auf Basis Server 2016" -ForegroundColor Green
     Write-Host "-------------------------------" -ForegroundColor Green
     Write-Host "3: DC02"
     Write-Host "4: App02"
     Write-Host 
     Write-Host "Maschinen auf Basis Server 2019" -ForegroundColor Green
     Write-Host "-------------------------------" -ForegroundColor Green
     Write-Host "5: DC03"
     Write-Host "6: App03"
     Write-Host
     Write-Host "Windows Client Maschinen" -ForegroundColor Green
     Write-Host "------------------------" -ForegroundColor Green
     Write-Host "7: Client01 - Windows 8.1"
     Write-Host "8: Client02 - Windows 10"
     Write-Host
     Write-Host "F: Fertig" -ForegroundColor Green
 }   

do
{
     Show-Menu
     $input = Read-Host "Welche VM soll erstellt werden?"
     switch ($input)
     {
             '1' {
                Write-Host 'Erstelle DC01'
                # Erstelle DC01 Basis Server 2012 R2
                Buildvm -VmName DC01 -OSBaseDisk $VMBaseDisk

           } '2' {
                Write-Host 'Erstelle App01'
                # Erstelle APP01 Basis Server 2012 R2
                Buildvm -VmName App01 -OSBaseDisk $VMBaseDisk

           }  'E' {
                Write-Host 'Erstelle Edge01'
                # Erstelle Edge01 Basis Server 2012 R2
                Buildvm -VmName Edge01 -OSBaseDisk $VMBaseDisk -SecondNetwork $true

            } 'I' {
                Write-Host 'Erstelle Inet01'
                # Erstelle Inet01 Basis Server 2012 R2
                Buildvm -VmName Inet01 -OSBaseDisk $VMBaseDisk
            
           } '3' {
                Write-Host 'Erstelle DC02'
                 # Erstelle DC02 Basis Server 2016
                 Buildvm -VmName DC02 -OSBaseDisk $VMBaseDisk16
            
           } '4' {
                Write-Host 'Erstelle App02'
                # Erstelle App02 Basis Server 2016
                Buildvm -VmName App02 -OSBaseDisk $VMBaseDisk16
           } '5' {
                Write-Host 'Erstelle DC03'
                 # Erstelle DC02 Basis Server 2016
                 Buildvm -VmName DC03 -OSBaseDisk $VMBaseDisk19
            
           } '6' {
                Write-Host 'Erstelle App03'
                # Erstelle App02 Basis Server 2016
                Buildvm -VmName App03 -OSBaseDisk $VMBaseDisk19
                
           } '7' {
                Write-Host 'Erstelle Client01'
                # Erstelle Client01 Basis Windows 8.1
                Buildvm -VmName Client01 -OSBaseDisk $VMBaseClient

            }'8' {
                Write-Host 'Erstelle Client02'
                # Erstelle Client02 Basis Windows 10
                Buildvm -VmName Client02 -OSBaseDisk $VMBase10Client
           
           } 'f' {
                break
           } default {Write-Warning 'Falsche Eingabe'}
     }
     write-host
     pause
}
until ($input -eq 'f')

# Automatische Prüfpunkte auf Win10 deaktivieren
if ((Get-CimInstance Win32_OperatingSystem).Name -like "*Windows 10*") {
    $vms=(get-vm).Name
    foreach ($computername in $vms) {Set-VM -name $computername -AutomaticCheckpointsEnabled $false
                                     Write-Host "Deaktiviere automatische Prüfpunkte für $computername"}
  }

pause
 