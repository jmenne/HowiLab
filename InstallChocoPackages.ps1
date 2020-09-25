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