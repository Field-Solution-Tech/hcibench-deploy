PS /home/holuser/Desktop/code> .\hcibench_deploy.ps1 -vCenterServer "vc-wld01-a.site-a.vcf.lab" -Username "administrator@wld.sso" -Password "VMware123!VMware123!" -OVAPath "/home/holuser/Downloads/HCIBench_2.8.3.ova" -VMName "HCIBench-01" -DatastoreName "cluster-wld01-01a-vsan01" -NetworkName "mgmt-vds01-wld01-01a" -ClusterName "cluster-wld01-01a" -RootPassword "VMware123!"
Connecting to vCenter: vc-wld01-a.site-a.vcf.lab
Found datastore: cluster-wld01-01a-vsan01
Looking for cluster: cluster-wld01-01a
Using cluster deployment
Looking for network 'mgmt-vds01-wld01-01a' on esx-07a.site-a.vcf.lab...
Found network: mgmt-vds01-wld01-01a
Deploying to: cluster-wld01-01a on host: esx-07a.site-a.vcf.lab
Reading OVA configuration...
Networks in OVA:
  Network 1: [empty/default]
Mapping all networks to: mgmt-vds01-wld01-01a
  Mapped 1 network(s)
Configuring DHCP networking
Deploying OVA...
Target host: esx-07a.site-a.vcf.lab
Target location: cluster-wld01-01a
Target datastore: cluster-wld01-01a-vsan01
Failed with folder, trying without folder...
Write-Error: Deployment failed: 6/24/2025 5:41:10 AM	Import-VApp		Host did not have any virtual network defined.	
PS /home/holuser/Desktop/code> 
