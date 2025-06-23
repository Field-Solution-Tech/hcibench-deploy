# Simple HCIBench OVA Deployment Script for Lab Use
# Deploys HCIBench OVA with DHCP or Static IP configuration

param(
    [Parameter(Mandatory=$true)]
    [string]$vCenterServer,
    
    [Parameter(Mandatory=$true)]
    [string]$Username,
    
    [Parameter(Mandatory=$true)]
    [string]$Password,
    
    [Parameter(Mandatory=$true)]
    [string]$OVAPath,
    
    [Parameter(Mandatory=$true)]
    [string]$VMName,
    
    [Parameter(Mandatory=$true)]
    [string]$DatastoreName,
    
    [Parameter(Mandatory=$true)]
    [string]$NetworkName,
    
    [string]$ClusterName,
    [string]$ResourcePoolName,
    
    # Network Settings - Leave IPAddress empty for DHCP
    [string]$IPAddress = "",        # Empty = DHCP, specify IP = Static
    [string]$Netmask = "24",        # CIDR format (24) or full mask (255.255.255.0)
    [string]$Gateway = "",
    [string]$DNS = "",
    
    [Parameter(Mandatory=$true)]
    [string]$RootPassword
)

# Import PowerCLI and disable warnings
Import-Module VMware.PowerCLI -ErrorAction Stop
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Scope Session | Out-Null

try {
    Write-Host "Connecting to vCenter: $vCenterServer" -ForegroundColor Green
    Connect-VIServer -Server $vCenterServer -User $Username -Password $Password -ErrorAction Stop | Out-Null
    
    # Get infrastructure objects
    $datastore = Get-Datastore -Name $DatastoreName -ErrorAction Stop
    $network = Get-VirtualPortGroup -Name $NetworkName -ErrorAction Stop
    
    # Determine deployment location
    if ($ClusterName) {
        $cluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
        $vmHost = $cluster | Get-VMHost | Where-Object {$_.ConnectionState -eq "Connected"} | Select-Object -First 1
        $location = if ($ResourcePoolName) { Get-ResourcePool -Name $ResourcePoolName -Location $cluster } else { $cluster }
    } else {
        $vmHost = Get-VMHost | Where-Object {$_.ConnectionState -eq "Connected"} | Select-Object -First 1
        $location = $vmHost
    }
    
    Write-Host "Deploying to: $($location.Name) on host: $($vmHost.Name)" -ForegroundColor Yellow
    
    # Get OVF configuration
    $ovfConfig = Get-OvfConfiguration -Ovf $OVAPath
    
    # Map networks
    foreach ($netKey in $ovfConfig.NetworkMapping.Keys) {
        $ovfConfig.NetworkMapping.$netKey = $network
    }
    
    # Configure OVF properties
    $useStaticIP = ![string]::IsNullOrEmpty($IPAddress)
    
    if ($useStaticIP) {
        Write-Host "Configuring Static IP: $IPAddress" -ForegroundColor Yellow
        $networkMode = "static"
    } else {
        Write-Host "Configuring DHCP networking" -ForegroundColor Yellow
        $networkMode = "dhcp"
    }
    
    # Find the property section (usually Common, vami, or similar)
    $propSection = $null
    @("Common", "vami", "Appliance") | ForEach-Object {
        if ($ovfConfig.PSObject.Properties[$_]) { $propSection = $ovfConfig.$_ }
    }
    
    if ($propSection) {
        # Set root password
        @("passwd", "password", "guestinfo.cis.appliance.root.passwd") | ForEach-Object {
            if ($propSection.PSObject.Properties[$_]) { 
                $propSection.$_.Value = $RootPassword
                Write-Host "Set root password" -ForegroundColor Green
            }
        }
        
        # Configure network based on mode
        if ($useStaticIP) {
            # Static IP configuration
            @("ip0", "guestinfo.cis.appliance.net.addr") | ForEach-Object {
                if ($propSection.PSObject.Properties[$_]) { $propSection.$_.Value = $IPAddress }
            }
            
            if ($Netmask) {
                $cidr = if ($Netmask -match '^\d{1,2}$') { $Netmask } else { 
                    switch ($Netmask) {
                        "255.255.255.0" { "24" }
                        "255.255.0.0" { "16" }
                        default { "24" }
                    }
                }
                @("netmask0", "guestinfo.cis.appliance.net.prefix") | ForEach-Object {
                    if ($propSection.PSObject.Properties[$_]) { 
                        $propSection.$_.Value = if ($_ -like "*prefix*") { $cidr } else { $Netmask }
                    }
                }
            }
            
            if ($Gateway) {
                @("gateway", "guestinfo.cis.appliance.net.gateway") | ForEach-Object {
                    if ($propSection.PSObject.Properties[$_]) { $propSection.$_.Value = $Gateway }
                }
            }
            
            if ($DNS) {
                @("DNS", "guestinfo.cis.appliance.net.dns.servers") | ForEach-Object {
                    if ($propSection.PSObject.Properties[$_]) { $propSection.$_.Value = $DNS }
                }
            }
        }
        
        # Set network mode
        @("guestinfo.cis.appliance.net.mode", "network_type") | ForEach-Object {
            if ($propSection.PSObject.Properties[$_]) { $propSection.$_.Value = $networkMode }
        }
    }
    
    # Deploy the OVA
    Write-Host "Deploying OVA..." -ForegroundColor Green
    $vm = Import-VApp -Source $OVAPath -OvfConfiguration $ovfConfig -Name $VMName `
        -Location $location -Datastore $datastore -VMHost $vmHost -ErrorAction Stop
    
    Write-Host "Starting VM..." -ForegroundColor Green
    Start-VM -VM $vm -Confirm:$false | Out-Null
    
    # Wait a moment and try to get IP
    Start-Sleep -Seconds 30
    $vm = Get-VM -Name $VMName
    
    Write-Host "`n=== Deployment Complete ===" -ForegroundColor Green
    Write-Host "VM Name: $($vm.Name)"
    Write-Host "Power State: $($vm.PowerState)"
    
    if ($useStaticIP) {
        Write-Host "IP Address: $IPAddress"
        Write-Host "Web Interface: https://$IPAddress:8443"
    } else {
        $assignedIP = $vm.Guest.IPAddress | Where-Object { $_ -ne "127.0.0.1" } | Select-Object -First 1
        if ($assignedIP) {
            Write-Host "DHCP IP: $assignedIP"
            Write-Host "Web Interface: https://$assignedIP:8443"
        } else {
            Write-Host "DHCP IP: Check VM console (may take a few minutes)"
            Write-Host "Web Interface: https://[VM_IP]:8443"
        }
    }
    
    Write-Host "`nLogin: root / $RootPassword" -ForegroundColor Cyan
    
} catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
} finally {
    if ($global:DefaultVIServers) {
        Disconnect-VIServer -Server * -Confirm:$false -Force
    }
}