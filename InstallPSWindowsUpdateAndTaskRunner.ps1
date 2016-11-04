# This script depends on the PackageManagementProviderResource module.
# Instructions on how to install these can be found here:
# https://azure.microsoft.com/en-gb/documentation/articles/automation-runbook-gallery/#modules-in-powershell-gallery

Configuration InstallPSWindowsUpdateAndTaskRunner
{
    Import-DscResource -ModuleName PackageManagementProviderResource

    Node Localhost
    {   
        PSModule InstallPSWindowsUpdate
		{
			Ensure = "Present"
			Name = "PSWindowsUpdate"
			InstallationPolicy = "Trusted"
			MinimumVersion = "1.5.2.2"
		}

		PSModule InstallTaskRunner
		{
			Ensure = "Present"
			Name = "TaskRunner"
			InstallationPolicy = "Trusted"
			MinimumVersion = "1.0"
		}
    }
}