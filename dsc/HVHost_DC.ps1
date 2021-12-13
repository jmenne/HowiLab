$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
If (-not $isAdmin) {
    Write-Host "-- Starte neu als Administrator" -ForegroundColor Cyan ; Start-Sleep -Seconds 1
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Remotesigned -File `"$PSCommandPath`"" -Verb RunAs
    exit
    }

$wuser = "Administrator"
$username = "corp\administrator"
$password = 'Pa$$w0rd'
$secpwd = ConvertTo-SecureString -AsPlainText -Force -String $password
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $secpwd
$wcred = new-object -typename System.Management.Automation.PSCredential -argumentlist $wuser, $secpwd

$session = New-PSSession -VMName DC04 -Credential $wcred
Invoke-Command -Session $session -ScriptBlock {

    Set-Location "c:\dsc"
    $Moduleda = Test-path 'C:\Program Files\WindowsPowerShell\Modules\xComputerManagement'
    If ($Moduleda -eq $false) {
        Write-Host "Kopiere DSC Module auf dem Zielrechner an die richtige Stelle" -ForegroundColor Green
        ./InstallDSCModules_DC.ps1
        # Auf Ferigstellung des Kopiervorgangs warten
        do {
        $Moduleda = Test-path 'C:\Program Files\WindowsPowerShell\Modules\xComputerManagement'
        Write-Host "." -NoNewline -ForegroundColor Cyan
        } until ($Moduleda -eq $True)
        Write-Host
    } 
    else { Write-host "DSC Module sind installiert" -ForegroundColor Yellow }

    # DSC Konfiguration vorbereiten
    Write-Host "LCM auf DC04 konfigurieren:" -ForegroundColor Green
    ./01-ConfigureLCM.ps1
    Write-Host "Erstelle MOF Datei für DC04:" -ForegroundColor Green
    ./02-ConfigureDC04.ps1

}

# DSC Konfiguration starten
Write-Host "Starte DSC Konfiguration auf DC04:" -ForegroundColor Green
Invoke-Command -Session $session -ScriptBlock { Start-DscConfiguration -Wait -Force -Path "c:\DSC\Config" }

do {
    $testdhcp = Invoke-Command -VMName "DC04" -ScriptBlock {(get-service -Name DHCPServer)} -ErrorAction Ignore -Credential $cred
    Write-Host "_-" -NoNewline
    Start-Sleep 4
   }
until ($testdhcp -ne $Null)
Write-Host
Write-Host "DC läuft!" -ForegroundColor Yellow
Pause

