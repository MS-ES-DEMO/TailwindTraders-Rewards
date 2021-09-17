[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

# Get Edge
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/matbe/PowerShell/master/Other/Get-EdgeEnterpriseMSI.ps1" -OutFile get-edge.ps1 -UseBasicParsing
.\get-edge.ps1 Stable .

# Install Edge
Start-Process powershell.exe -ArgumentList '.\MicrosoftEdgeEnterpriseX64.msi', '/q' -Wait

# Cleanup Edge msi
rm .\MicrosoftEdgeEnterpriseX64.msi

# Install Windows Features
Install-WindowsFeature Web-Server
Install-WindowsFeature Web-Net-Ext  
Install-WindowsFeature Web-Net-Ext45
Install-WindowsFeature Web-AppInit                   
Install-WindowsFeature Web-ASP                       
Install-WindowsFeature Web-Asp-Net                    
Install-WindowsFeature Web-Asp-Net45                   
Install-WindowsFeature Web-Includes                   
Install-WindowsFeature Web-WebSockets
Install-WindowsFeature Web-Mgmt-Tools
Install-WindowsFeature Web-Scripting-Tools
Install-WindowsFeature Web-Mgmt-Service
Install-WindowsFeature WinRM-IIS-Ext

# Get webdeploy
Invoke-WebRequest -Uri "https://aka.ms/webdeploy3.6" -OutFile webdeploy.msi -UseBasicParsing

# Install webdeploy
Start-Process powershell.exe -ArgumentList '.\webdeploy.msi', '/q' -Wait

# Cleanup webdeploy msi
rm .\webdeploy.msi

# Get AppContainerizationInstaller
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2134571" -OutFile AppContainerizationInstaller.ps1 -UseBasicParsing

# Install AppContainerizationInstaller
.\AppContainerizationInstaller.ps1

# Cleanup AppContainerizationInstaller
rm .\AppContainerizationInstaller.msi

$run_on_logon = {
# Get SQL Express
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=866658" -OutFile sql_express_setup.exe -UseBasicParsing 

# Install SQL Express
. .\sql_express_setup.exe /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION="Install" /ENU /INSTALLPATH="C:\Program Files\Microsoft SQL Server" | Write-Output

# Cleanup SQL Express
rm .\sql_express_setup.exe

$Env:PATH = $Env:PATH + ";C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn"
sqlcmd.exe -E -S .\SQLEXPRESS -Q "CREATE DATABASE rewardsdb"
sqlcmd.exe -E -S .\SQLEXPRESS -Q "USE rewardsdb; GRANT execute on schema :: dbo to [IIS APPPOOL\DefaultAppPool]"
sqlcmd.exe -E -S .\SQLEXPRESS -Q "USE rewardsdb; ALTER ROLE db_owner ADD MEMBER [IIS APPPOOL\DefaultAppPool]"

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/MS-ES-DEMO/TailwindTraders-Rewards/main/Source/SQLScripts/CreateTablesAndPopulate.sql" -OutFile sql_script.sql -UseBasicParsing
sqlcmd.exe -E -S .\SQLEXPRESS -i .\sql_script.sql

# Cleanup Script
rm .\sql_script.sql

# Clean C:\inetpub\wwwroot
rm C:\inetpub\wwwroot\*.*
rm -r -fo C:\inetpub\wwwroot\aspnet_client\

Invoke-WebRequest -Uri "https://github.com/MS-ES-DEMO/TailwindTraders-Rewards/releases/download/v0.1.0/TailwindTradersBundle.zip" -OutFile TailwindTradersBundle.zip -UseBasicParsing
Expand-Archive -Path .\TailwindTradersBundle.zip -DestinationPath C:\inetpub\wwwroot\

# Cleanup Zip
rm .\TailwindTradersBundle.zip

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "SetupSQLAndAppLogonScript" -Confirm:$false
}

echo $run_on_logon.ToString() > C:\run_on_logon.ps1

# Creating scheduled task for MonitorWorkbookLogonScript.ps1
$trigger = New-ScheduledTaskTrigger -AtLogOn
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "C:\run_on_logon.ps1"
Register-ScheduledTask -TaskName "SetupSQLAndAppLogonScript" -Trigger $Trigger -User "as-is-user" -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask