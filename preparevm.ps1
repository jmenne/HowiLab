# DataDisk initialisieren, partitionieren, formatieren 
Get-Disk | Where partitionstyle -eq 'raw' | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -UseMaximumSize -DriveLetter F | Format-Volume -FileSystem NTFS -NewFileSystemLabel "data" -Confirm:$false -Force

# Az-104 Repo runterladen
$location = "c:\az104"
$zipfile = "$loction\az104repo.zip"

New-Item $zipfile -ItemType File -Force

#$RepositoryZipUrl = "https://github.com/MicrosoftLearning/AZ-104-MicrosoftAzureAdministrator/archive/master.zip"
# oder
$RepositoryZipUrl = "https://api.github.com/repos/MicrosoftLearning/AZ-104-MicrosoftAzureAdministrator/zipball/master"

Invoke-RestMethod -Uri $RepositoryZipUrl -OutFile $ZipFile
Expand-Archive -Path $zipfile -DestinationPath $location -force

# jetzt noch allfiles / Instructions kopieren

# Powershell Module Az, Msonline, AzureAD installieren
Install-PackageProvider -Name Nuget -Force

Set-PSRepository -Name PsGallery -InstallationPolicy Trusted 

Install-Module Az -AllowClobber -Force
Install-Module MSOnline -AllowClobber -Force
Install-Module AzureAD -AllowClobber -Force

#Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

#Assign Packages to Install
$Packages = 'vscode',`
            'azure-cli',`
            'foxitreader' ,`
            'microsoftazurestorageexplorer',`
            'sql-server-management-studio'
          
#Install Packages
ForEach ($PackageName in $Packages)
{choco install $PackageName -y}

#Reboot
Restart-Computer