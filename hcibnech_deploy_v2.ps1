# Alternative deployment approach for pure DVS environments
# This script uses a different method to deploy the OVA

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
    
    [Parameter(Mandatory=$true)]
    [string]$RootPassword
)

# Import PowerCLI
Import-Module VMware.PowerCLI -ErrorAction Stop
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Scope Session | Out-Null

function Find-ExistingPortgroup {
    param($VMHost)
    
    # Look for any existing standard portgroup we can use temporarily
    $existingPG = Get-VirtualPortGroup -VMHost $VMHost -Standard | 
                  Where-Object { $_.Name -ne "VM Network" } | 
                  Select-Object -First 1
    
    if (!$existingPG) {
        # If no other portgroups, check if VM Network exists
        $existingPG = Get-VirtualPortGroup -VMHost $VMHost -Standard -Name "VM Network" -ErrorAction SilentlyContinue
    }
    
    return $existingPG
}

try {
    Write-Host "=== HCIBench Deployment Starting ===" -ForegroundColor Green
    Write-Host "Using alternative deployment method for pure DVS environment" -ForegroundColor Cyan
    
    # Connect to vCenter
    Write-Host "Connecting to vCenter: $vCenterServer" -ForegroundColor Yellow
    Connect-VIServer -Server $vCenterServer -User $Username -Password $Password -ErrorAction Stop | Out-Null
    
    # Get resources
    $cluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
    Write-Host "✓ Found cluster: $($cluster.Name)" -ForegroundColor Green
    
    $datastore = Get-Datastore -Name $DatastoreName -ErrorAction Stop
    Write-Host "✓ Found datastore: $($datastore.Name)" -ForegroundColor Green
    
    # Get DVS portgroup
    $targetNetwork = Get-VDPortgroup -Name $NetworkName -ErrorAction Stop
    Write-Host "✓ Found DVS portgroup: $($targetNetwork.Name)" -ForegroundColor Green
    
    # Get host
    $vmHost = $cluster | Get-VMHost | Where-Object { 
        $_.ConnectionState -eq "Connected" -and 
        ($_ | Get-Datastore -Name $DatastoreName -ErrorAction SilentlyContinue)
    } | Select-Object -First 1
    
    Write-Host "✓ Selected host: $($vmHost.Name)" -ForegroundColor Green
    
    # Method 1: Try using ovftool from PowerShell
    Write-Host "`nAttempting deployment using ovftool..." -ForegroundColor Yellow
    
    # Check if ovftool is available
    $ovftoolPath = $null
    $possiblePaths = @(
        "C:\Program Files\VMware\VMware OVF Tool\ovftool.exe",
        "C:\Program Files (x86)\VMware\VMware OVF Tool\ovftool.exe",
        "/usr/bin/ovftool",
        "/usr/local/bin/ovftool"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $ovftoolPath = $path
            break
        }
    }
    
    # Check if ovftool is in PATH
    if (!$ovftoolPath) {
        $ovftoolCmd = Get-Command ovftool -ErrorAction SilentlyContinue
        if ($ovftoolCmd) {
            $ovftoolPath = "ovftool"
        }
    }
    
    if ($ovftoolPath) {
        Write-Host "✓ Found ovftool: $ovftoolPath" -ForegroundColor Green
        
        # Build ovftool command
        $target = "vi://$Username@$vCenterServer/$ClusterName/host"
        
        $ovftoolArgs = @(
            "--noSSLVerify",
            "--acceptAllEulas",
            "--diskMode=thin",
            "--datastore=`"$DatastoreName`"",
            "--network=`"$NetworkName`"",
            "--name=`"$VMName`"",
            "--prop:password=`"$RootPassword`"",
            "--powerOn",
            "`"$OVAPath`"",
            "`"$target`""
        )
        
        Write-Host "Deploying OVA with ovftool..." -ForegroundColor Yellow
        Write-Host "Command: $ovftoolPath $($ovftoolArgs -join ' ')" -ForegroundColor Gray
        
        # Create secure string for password
        $secPassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($Username, $secPassword)
        
        # Execute ovftool
        $ovftoolProcess = Start-Process -FilePath $ovftoolPath `
                                      -ArgumentList $ovftoolArgs `
                                      -NoNewWindow `
                                      -PassThru `
                                      -Wait `
                                      -RedirectStandardOutput "ovftool_output.txt" `
                                      -RedirectStandardError "ovftool_error.txt"
        
        if ($ovftoolProcess.ExitCode -eq 0) {
            Write-Host "✓ OVA deployed successfully with ovftool!" -ForegroundColor Green
            
            # Get the deployed VM
            Start-Sleep -Seconds 5
            $vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
            
            if ($vm) {
                Write-Host "`n=== Deployment Complete ===" -ForegroundColor Green
                Write-Host "VM Name: $($vm.Name)"
                Write-Host "Power State: $($vm.PowerState)"
                Write-Host "Host: $($vm.VMHost.Name)"
                Write-Host "Network: $NetworkName (DVS)"
                
                # Wait for IP
                Write-Host "`nWaiting for IP address..." -ForegroundColor Yellow
                $timeout = 120
                $elapsed = 0
                while ($elapsed -lt $timeout) {
                    $vm = Get-VM -Name $VMName
                    $ip = $vm.Guest.IPAddress | Where-Object { $_ -ne "127.0.0.1" -and $_ -notlike "fe80:*" } | Select-Object -First 1
                    if ($ip) {
                        Write-Host "✓ IP Address: $ip" -ForegroundColor Green
                        Write-Host "Web Interface: https://$ip:8443" -ForegroundColor Cyan
                        break
                    }
                    Start-Sleep -Seconds 10
                    $elapsed += 10
                    Write-Host "." -NoNewline
                }
                
                Write-Host "`nLogin: root / $RootPassword" -ForegroundColor Cyan
            }
        } else {
            Write-Host "✗ ovftool deployment failed. Check ovftool_error.txt for details" -ForegroundColor Red
            if (Test-Path "ovftool_error.txt") {
                Get-Content "ovftool_error.txt" | Write-Host -ForegroundColor Red
            }
        }
        
    } else {
        Write-Host "✗ ovftool not found" -ForegroundColor Red
        Write-Host "`nAlternative: Deploy manually through vCenter UI" -ForegroundColor Yellow
        Write-Host "1. In vCenter, right-click on cluster '$ClusterName'" -ForegroundColor White
        Write-Host "2. Select 'Deploy OVF Template'" -ForegroundColor White
        Write-Host "3. Browse to: $OVAPath" -ForegroundColor White
        Write-Host "4. Select datastore: $DatastoreName" -ForegroundColor White
        Write-Host "5. Select network: $NetworkName" -ForegroundColor White
        Write-Host "6. Set root password: $RootPassword" -ForegroundColor White
        Write-Host "7. Complete the wizard" -ForegroundColor White
    }
    
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nFor pure DVS environments, consider:" -ForegroundColor Yellow
    Write-Host "1. Install ovftool and use the bash script provided" -ForegroundColor White
    Write-Host "2. Deploy through vCenter UI manually" -ForegroundColor White
    Write-Host "3. Use Content Library deployment method" -ForegroundColor White
} finally {
    # Cleanup
    Remove-Item "ovftool_output.txt", "ovftool_error.txt" -ErrorAction SilentlyContinue
    
    if ($global:DefaultVIServers) {
        Disconnect-VIServer -Server * -Confirm:$false -Force
        Write-Host "Disconnected from vCenter" -ForegroundColor Gray
    }
}
