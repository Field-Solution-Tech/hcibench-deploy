PS /home/holuser/Desktop/code> .\hcibench_deploy.ps1 -vCenterServer "vc-wld01-a.site-a.vcf.lab" -Username "administrator@wld.sso" -Password "VMware123!VMware123!" -OVAPath "/home/holuser/Downloads/HCIBench_2.8.3.ova" -VMName "HCIBench-01" -DatastoreName "cluster-wld01-01a-vsan01" -NetworkName "mgmt-vds01-wld01-01a" -ClusterName "cluster-wld01-01a" -RootPassword "VMware123!"
=== HCIBench Deployment Starting ===
Connecting to vCenter: vc-wld01-a.site-a.vcf.lab
Getting cluster: cluster-wld01-01a
✓ Found cluster: cluster-wld01-01a
Getting datastore: cluster-wld01-01a-vsan01
✓ Found datastore: cluster-wld01-01a-vsan01 [vsan]
Getting network: mgmt-vds01-wld01-01a
✓ Found DVS portgroup: mgmt-vds01-wld01-01a
Selecting deployment target...
✓ Using cluster as location: cluster-wld01-01a
✓ Selected host: esx-07a.site-a.vcf.lab
Reading OVA configuration...
✓ OVA configuration loaded
Configuring network mappings...
OVA networks found:
  Network 1: Management_Network
    Method 1 failed, trying alternative...
    Method 2 failed, trying hashtable approach...
    ✗ All mapping methods failed: Operation is not valid due to the current state of the object.
    Continuing without network mapping...
  Network 2: VM_Network
    Method 1 failed, trying alternative...
    Method 2 failed, trying hashtable approach...
    ✗ All mapping methods failed: Operation is not valid due to the current state of the object.
    Continuing without network mapping...
✓ Processed 2 network mapping(s)
Network configuration: DHCP
✓ Using OVF property section: Common
✓ DHCP configuration (no additional setup needed)
=== Starting OVA Deployment ===
Source: /home/holuser/Downloads/HCIBench_2.8.3.ova
Target: esx-07a.site-a.vcf.lab in cluster-wld01-01a
Datastore: cluster-wld01-01a-vsan01
Network: mgmt-vds01-wld01-01a [DVS]
✗ Deployment failed: 6/24/2025 5:54:24 AM	Import-VApp		Host did not have any virtual network defined.	
Full error: VMware.VimAutomation.ViCore.Types.V1.ErrorHandling.OvfNoHostNic: 6/24/2025 5:54:24 AM	Import-VApp		Host did not have any virtual network defined.	
   at VMware.VimAutomation.ViCore.Impl.V1.Service.VappServiceImpl.ImportVApp(FileInfo ovfDescriptor, VMHostInterop host, StorageResourceInterop datastore, VIContainerInterop location, FolderContainerInterop inventoryLocation, String importName, Nullable`1 diskStorageFormat, Hashtable ovfPropertySpec, Boolean force)
   at VMware.VimAutomation.ViCore.Cmdlets.Commands.ImportVApp.DoWork(VIAutomation client, List`1 moList)
Disconnected from vCenter
