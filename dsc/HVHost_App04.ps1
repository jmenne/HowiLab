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

$session = New-PSSession -VMName App04 -Credential $wcred
Invoke-Command -Session $session -ScriptBlock {

    Set-Location "c:\dsc"
    $Moduleda = Test-path 'C:\Program Files\WindowsPowerShell\Modules\xComputerManagement'
    If ($Moduleda -eq $false) {
        Write-Host "Kopiere DSC Module auf dem Zielrechner an die richtige Stelle" -ForegroundColor Green
        ./InstallDSCModules_App.ps1
        # Auf Ferigstellung des Kopiervorgangs warten
        do {
        $Moduleda = Test-path 'C:\Program Files\WindowsPowerShell\Modules\xComputerManagement'
        Write-Host "." -NoNewline -ForegroundColor Cyan
        } until ($Moduleda -eq $True)
        Write-Host
    } 
    else { Write-host "DSC Module sind installiert" -ForegroundColor Yellow }

    # DSC Konfiguration vorbereiten
    Write-Host "LCM auf App04 konfigurieren:" -ForegroundColor Green
    ./01-ConfigureLCM.ps1
    Write-Host "Erstelle MOF Datei für App04:" -ForegroundColor Green
    ./03-ConfigureApp04.ps1

}

# DSC Konfiguration starten
Write-Host "Starte DSC Konfiguration auf App04:" -ForegroundColor Green
Invoke-Command -Session $session -ScriptBlock { Start-DscConfiguration -Wait -Force -Path "c:\DSC\Config" }

# Namen des DCs ermitteln
$DCName=(get-vm | where-object {$_.Name -like "DC*"}).name

do {
    $testapp = Invoke-Command -VMName $DCName -ScriptBlock {get-adcomputer -filter * -searchbase "OU=Servers,OU=HowiLab,dc=corp,dc=howilab,dc=local"} -Credential $cred -ErrorAction Ignore

    $filesda = Invoke-Command -VMName "App04" -ScriptBlock { (Test-path 'C:\Files\')} -Credential $cred -ErrorAction Ignore
    Write-Host "_-" -NoNewline
    Start-Sleep 4
   }
until (($filesda -eq $True) -and ($testapp.name -eq "App04"))
Write-Host
Write-Host "App04 ist eingerichtet!" -ForegroundColor Yellow
Pause
