[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

# Get Edge
$get_edge_location="https://raw.githubusercontent.com/matbe/PowerShell/master/Other/Get-EdgeEnterpriseMSI.ps1"
Invoke-WebRequest -Uri $get_edge_location -OutFile get-edge.ps1 -UseBasicParsing
.\get-edge.ps1 Stable .

# Install Edge
.\MicrosoftEdgeEnterpriseX64.msi /q

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

$run_on_logon = {
# Get SQL Express
$sql_express_location="https://go.microsoft.com/fwlink/?linkid=866658"
Invoke-WebRequest -Uri $sql_express_location -OutFile sql_express_setup.exe -UseBasicParsing 

# Install SQL Express
.\sql_express_setup.exe /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION="Install" /ENU /INSTALLPATH="C:\Program Files\Microsoft SQL Server"

# Cleanup SQL Express
rm .\sql_express_setup.exe

$Env:PATH = $Env:PATH + ";C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn"
sqlcmd.exe -E -S .\SQLEXPRESS -Q "CREATE DATABASE rewardsdb"
sqlcmd.exe -E -S .\SQLEXPRESS -Q "USE rewardsdb; GRANT execute on schema :: dbo to [IIS APPPOOL\DefaultAppPool]"
sqlcmd.exe -E -S .\SQLEXPRESS -Q "USE rewardsdb; ALTER ROLE db_owner ADD MEMBER [IIS APPPOOL\DefaultAppPool]"

$sql_script="https://raw.githubusercontent.com/MS-ES-DEMO/TailwindTraders-Rewards/main/Source/SQLScripts/CreateTablesAndPopulate.sql"
Invoke-WebRequest -Uri $sql_script -OutFile sql_script.sql -UseBasicParsing
sqlcmd.exe -E -S .\SQLEXPRESS -i .\sql_script.sql

# Cleanup Script
rm .\sql_script.sql

# Clean C:\inetpub\wwwroot
rm C:\inetpub\wwwroot\*.*
rm -r -fo C:\inetpub\wwwroot\aspnet_client\

$app="https://github.com/MS-ES-DEMO/TailwindTraders-Rewards/releases/download/v0.1.0/TailwindTradersBundle.zip"
Invoke-WebRequest -Uri $app -OutFile TailwindTradersBundle.zip -UseBasicParsing
Expand-Archive -Path .\TailwindTradersBundle.zip -DestinationPath C:\inetpub\wwwroot\

# Cleanup Zip
rm .\TailwindTradersBundle.zip

SCHTASKS.EXE /DELETE /F /TN "First Logon"
}

echo $run_on_logon.ToString() > C:\run_on_logon.ps1
SCHTASKS.EXE /CREATE /F /SC ONLOGON /TN "First Logon" /RL HIGHEST /TR "powershell.exe -ExecutionPolicy Bypass -File C:\run_on_logon.ps1"