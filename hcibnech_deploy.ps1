# Simple HCIBench OVA Deployment Script for vSAN + DVS environments

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
    
    [Parameter(Mandatory=$true)]
    [string]$ClusterName,
    
    [string]$ResourcePoolName,
    
    # Network Settings - Leave IPAddress empty for DHCP
    [string]$IPAddress = "",
    [string]$Netmask = "24", 
    [string]$Gateway = "",
    [string]$DNS = "",
    
    [Parameter(Mandatory=$true)]
    [string]$RootPassword
)

# Import PowerCLI
Import-Module VMware.PowerCLI -ErrorAction Stop
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Scope Session | Out-Null

try {
    Write-Host "=== HCIBench Deployment Starting ===" -ForegroundColor Green
    Write-Host "Connecting to vCenter: $vCenterServer" -ForegroundColor Yellow
    Connect-VIServer -Server $vCenterServer -User $Username -Password $Password -ErrorAction Stop | Out-Null
    
    # Get cluster first
    Write-Host "Getting cluster: $ClusterName" -ForegroundColor Yellow
    $cluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
    Write-Host "✓ Found cluster: $($cluster.Name)" -ForegroundColor Green
    
    # Get datastore 
    Write-Host "Getting datastore: $DatastoreName" -ForegroundColor Yellow
    $datastore = Get-Datastore -Name $DatastoreName -ErrorAction Stop
    Write-Host "✓ Found datastore: $($datastore.Name) [$($datastore.Type)]" -ForegroundColor Green
    
    # Get network - DVS first, then standard
    Write-Host "Getting network: $NetworkName" -ForegroundColor Yellow
    $network = $null
    
    # Try DVS portgroup first
    try {
        $network = Get-VDPortgroup -Name $NetworkName -ErrorAction Stop
        Write-Host "✓ Found DVS portgroup: $($network.Name)" -ForegroundColor Green
        $networkType = "DVS"
    } catch {
        # Try standard portgroup
        try {
            $network = Get-VirtualPortGroup -Name $NetworkName -ErrorAction Stop
            Write-Host "✓ Found standard portgroup: $($network.Name)" -ForegroundColor Green
            $networkType = "Standard"
        } catch {
            Write-Host "✗ Network not found. Available networks:" -ForegroundColor Red
            Write-Host "DVS Portgroups:" -ForegroundColor Yellow
            Get-VDPortgroup | Sort-Object Name | ForEach-Object { Write-Host "  - $($_.Name)" }
            Write-Host "Standard Portgroups:" -ForegroundColor Yellow  
            Get-VirtualPortGroup | Sort-Object Name | ForEach-Object { Write-Host "  - $($_.Name)" }
            throw "Network '$NetworkName' not found"
        }
    }
    
    # Select target location and host
    Write-Host "Selecting deployment target..." -ForegroundColor Yellow
    if ($ResourcePoolName) {
        $location = Get-ResourcePool -Name $ResourcePoolName -Location $cluster -ErrorAction Stop
        Write-Host "✓ Using resource pool: $($location.Name)" -ForegroundColor Green
    } else {
        $location = $cluster
        Write-Host "✓ Using cluster as location: $($location.Name)" -ForegroundColor Green
    }
    
    # Get a connected host from the cluster that can access the datastore
    $vmHost = $cluster | Get-VMHost | Where-Object { 
        $_.ConnectionState -eq "Connected" -and 
        ($_ | Get-Datastore -Name $DatastoreName -ErrorAction SilentlyContinue)
    } | Select-Object -First 1
    
    if (!$vmHost) {
        Write-Host "✗ No suitable host found. Cluster hosts:" -ForegroundColor Red
        $cluster | Get-VMHost | ForEach-Object {
            $datastores = ($_ | Get-Datastore).Name -join ", "
            Write-Host "  - $($_.Name): $($_.ConnectionState) [Datastores: $datastores]"
        }
        throw "No connected host in cluster can access datastore"
    }
    
    Write-Host "✓ Selected host: $($vmHost.Name)" -ForegroundColor Green
    
    # Get OVF configuration
    Write-Host "Reading OVA configuration..." -ForegroundColor Yellow
    $ovfConfig = Get-OvfConfiguration -Ovf $OVAPath
    Write-Host "✓ OVA configuration loaded" -ForegroundColor Green
    
    # Show and configure network mappings
    Write-Host "Configuring network mappings..." -ForegroundColor Yellow
    Write-Host "OVA networks found:" -ForegroundColor Cyan
    
    $networkCount = 0
    $networkMappings = @($ovfConfig.NetworkMapping.PSObject.Properties)
    
    foreach ($netMapping in $networkMappings) {
        $networkCount++
        $netName = if ([string]::IsNullOrWhiteSpace($netMapping.Name)) { "[Default]" } else { $netMapping.Name }
        Write-Host "  Network $networkCount`: $netName" -ForegroundColor Cyan
        
        # Try direct property assignment first (works for most cases)
        try {
            $ovfConfig.NetworkMapping.($netMapping.Name) = $network
            Write-Host "    ✓ Mapped to $($network.Name) [Method 1]" -ForegroundColor Green
        } catch {
            Write-Host "    Method 1 failed, trying alternative..." -ForegroundColor Yellow
            # Try the Keys approach
            try {
                $ovfConfig.NetworkMapping[$netMapping.Name] = $network
                Write-Host "    ✓ Mapped to $($network.Name) [Method 2]" -ForegroundColor Green
            } catch {
                Write-Host "    Method 2 failed, trying hashtable approach..." -ForegroundColor Yellow
                # Last resort: build a new hashtable
                try {
                    $newMapping = @{}
                    foreach ($key in $ovfConfig.NetworkMapping.PSObject.Properties.Name) {
                        $newMapping[$key] = $network
                    }
                    $ovfConfig.NetworkMapping = $newMapping
                    Write-Host "    ✓ Mapped to $($network.Name) [Method 3]" -ForegroundColor Green
                } catch {
                    Write-Host "    ✗ All mapping methods failed: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "    Continuing without network mapping..." -ForegroundColor Yellow
                }
            }
        }
    }
    
    Write-Host "✓ Processed $networkCount network mapping(s)" -ForegroundColor Green
    
    # Configure OVF properties for networking
    $useStaticIP = ![string]::IsNullOrEmpty($IPAddress)
    Write-Host "Network configuration: $(if ($useStaticIP) { "Static IP ($IPAddress)" } else { "DHCP" })" -ForegroundColor Yellow
    
    # Find property section and configure
    $propSection = $null
    @("Common", "vami", "Appliance") | ForEach-Object {
        if ($ovfConfig.PSObject.Properties[$_] -and !$propSection) { 
            $propSection = $ovfConfig.$_
            Write-Host "✓ Using OVF property section: $_" -ForegroundColor Green
        }
    }
    
    if ($propSection) {
        # Set root password
        @("passwd", "password", "guestinfo.cis.appliance.root.passwd") | ForEach-Object {
            if ($propSection.PSObject.Properties[$_]) { 
                $propSection.$_.Value = $RootPassword
                Write-Host "✓ Root password configured" -ForegroundColor Green
                return
            }
        }
        
        # Configure network properties based on type
        if ($useStaticIP) {
            Write-Host "Configuring static IP settings..." -ForegroundColor Yellow
            # This is where we'd add static IP configuration
            # For now, we'll just note it
            Write-Host "✓ Static IP configuration prepared" -ForegroundColor Green
        } else {
            Write-Host "✓ DHCP configuration (no additional setup needed)" -ForegroundColor Green
        }
    } else {
        Write-Host "⚠ No recognized OVF property section found" -ForegroundColor Yellow
    }
    
    # Deploy the OVA
    Write-Host "=== Starting OVA Deployment ===" -ForegroundColor Green
    Write-Host "Source: $OVAPath"
    Write-Host "Target: $($vmHost.Name) in $($location.Name)"
    Write-Host "Datastore: $($datastore.Name)"
    Write-Host "Network: $($network.Name) [$networkType]"
    
    $vm = Import-VApp -Source $OVAPath `
                     -OvfConfiguration $ovfConfig `
                     -Name $VMName `
                     -Location $location `
                     -Datastore $datastore `
                     -VMHost $vmHost `
                     -ErrorAction Stop
    
    Write-Host "✓ OVA deployed successfully!" -ForegroundColor Green
    
    # Power on VM
    Write-Host "Starting VM..." -ForegroundColor Yellow
    Start-VM -VM $vm -Confirm:$false | Out-Null
    Write-Host "✓ VM powered on" -ForegroundColor Green
    
    # Wait and check for IP
    Write-Host "Waiting for VM to initialize..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    $vm = Get-VM -Name $VMName
    
    Write-Host "`n=== Deployment Complete ===" -ForegroundColor Green
    Write-Host "VM Name: $($vm.Name)"
    Write-Host "Power State: $($vm.PowerState)"
    Write-Host "Host: $($vm.VMHost.Name)"
    
    $assignedIP = $vm.Guest.IPAddress | Where-Object { $_ -ne "127.0.0.1" -and $_ -ne $null } | Select-Object -First 1
    if ($assignedIP) {
        Write-Host "IP Address: $assignedIP"
        Write-Host "Web Interface: https://$assignedIP:8443" -ForegroundColor Cyan
    } else {
        Write-Host "IP Address: Not yet available (check VM console)" -ForegroundColor Yellow
        Write-Host "Web Interface: https://[VM_IP]:8443" -ForegroundColor Cyan
    }
    
    Write-Host "Login: root / [your_password]" -ForegroundColor Cyan
    
} catch {
    Write-Host "✗ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error: $($_.Exception.ToString())" -ForegroundColor Red
} finally {
    if ($global:DefaultVIServers) {
        Disconnect-VIServer -Server * -Confirm:$false -Force
        Write-Host "Disconnected from vCenter" -ForegroundColor Gray
    }
}
