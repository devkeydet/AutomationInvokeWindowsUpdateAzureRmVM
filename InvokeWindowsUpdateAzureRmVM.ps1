# For simplicity, this script accesses the VM using PowerShell Remoting over ssl using via public IP/DNS label.  
# If you prefer to not expose VMs over the public internet you could consider using Azure Automation Hybrid Runbook Workers:
# https://azure.microsoft.com/en-us/documentation/articles/automation-hybrid-runbook-worker/#starting-runbooks-on-hybrid-runbook-worker
#
# This script assumes that WinRM is already configured on the VM using a self signed cert.  
# There are a number of ways to accomplish this.  See the below for some examples examples:
# https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-winrm/ 
# http://www.techdiction.com/?s=WinRM

Param(
   [string]$EnvironmentName = "AzureCloud",
   [Parameter(mandatory=$true)]
   [string]$ComputerName, #example: "*.eastus.cloudapp.azure.com *or* IP"
   [Parameter(mandatory=$true)]
   [string]$PSCredentialName
)

$Conn = Get-AutomationConnection -Name AzureRunAsConnection
 
Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationID $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint -EnvironmentName $EnvironmentName

$Credential = Get-AutomationPSCredential -Name $PSCredentialName

Write-Output "Connecting to VM and installing updates..."

# This script assumes that WinRM is already configured on the VM using a self signed cert.  
# There are a number of ways to accomplish this.  See the instructions below for examples:
# https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-winrm/
Try
{
    Invoke-Command -ComputerName $ComputerName -UseSSL -Credential $Credential -ErrorAction Stop `
        -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck) -Authentication Negotiate `
        -ScriptBlock `
        {
            # Script assumes the following moduels are installed on the remote computer
            # https://www.powershellgallery.com/packages/PSWindowsUpdate/1.5.2.2
            # https://www.powershellgallery.com/packages/TaskRunner/1.0
            #
            # There are a number of ways to get these on the VM.  In my example:
            # [INSERT BLOG URL]
            # ...I use Azure Automation DSC:
            # https://azure.microsoft.com/en-us/documentation/articles/automation-dsc-overview/
            # You can get instructions on how to download the script and deploy in the blog post above. 
            New-Item C:\UpdateWindows.ps1 -type file -force `
                -value "Get-WUInstall -AcceptAll -AutoReboot -IgnoreUserInput | Out-File C:\PSWindowsUpdate.log"
            RunTask -coreScriptFilePath "C:\UpdateWindows.ps1" -waitForCompletion $true -cleanup $true        
        }
}
Catch
{
    Write-Output "Failed to connect to VM.  Exiting..."
    Exit
}

Write-Output "Checking for reboot..."

#Sleep for 30 seconds, then check if rebooting
Start-Sleep -s 30


$UnableToReconnect = $true
$Logs = $null

#If we can reconnect, then there was no reboot.  If we can't then there was a reboot.  Keep trying to reconnect until successful 
While ($UnableToReconnect)
{
    Try
    {
        $Logs = Invoke-Command -ComputerName $ComputerName -UseSSL -Credential $Credential -ErrorAction Stop `
            -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck) -Authentication Negotiate `
            -ScriptBlock `
            {
                Get-Content "C:\PSWindowsUpdate.log"
            }
        $UnableToReconnect = $false
    }
    Catch
    {
        Write-Output "Reboot in progress.  Trying again in 30 seconds..."
        Start-Sleep -s 30
    }
}

If($Logs -eq $null)
{
    Write-Output "No Updates applied to the VM."
}
Else
{
    $Logs
}