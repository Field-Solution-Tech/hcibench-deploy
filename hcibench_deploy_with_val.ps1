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
✗ Deployment failed: Exception setting "Value": "Operation is not valid due to the current state of the object."
Full error: System.Management.Automation.SetValueInvocationException: Exception setting "Value": "Operation is not valid due to the current state of the object."
 ---> System.InvalidOperationException: Operation is not valid due to the current state of the object.
   at VMware.VimAutomation.Sdk.Util10Ps.ObjectCustomization.SimpleExtensionProperty.set_Value(Object value)
   at CallSite.Target(Closure, CallSite, Object, Object)
   --- End of inner exception stack trace ---
   at System.Management.Automation.ExceptionHandlingOps.CheckActionPreference(FunctionContext funcContext, Exception exception) in /root/parts/powershell/build/src/System.Management.Automation/engine/runtime/Operations/MiscOps.cs:line 1791
   at System.Management.Automation.Interpreter.ActionCallInstruction`2.Run(InterpretedFrame frame) in /root/parts/powershell/build/src/System.Management.Automation/engine/interpreter/CallInstruction.Generated.cs:line 504
   at System.Management.Automation.Interpreter.EnterTryCatchFinallyInstruction.Run(InterpretedFrame frame) in /root/parts/powershell/build/src/System.Management.Automation/engine/interpreter/ControlFlowInstructions.cs:line 389
   at System.Management.Automation.Interpreter.EnterTryCatchFinallyInstruction.Run(InterpretedFrame frame) in /root/parts/powershell/build/src/System.Management.Automation/engine/interpreter/ControlFlowInstructions.cs:line 355
   at System.Management.Automation.Interpreter.Interpreter.Run(InterpretedFrame frame) in /root/parts/powershell/build/src/System.Management.Automation/engine/interpreter/Interpreter.cs:line 105
   at System.Management.Automation.Interpreter.LightLambda.RunVoid1[T0](T0 arg0) in /root/parts/powershell/build/src/System.Management.Automation/engine/interpreter/LightLambda.Generated.cs:line 81
   at System.Management.Automation.ScriptBlock.InvokeWithPipeImpl(ScriptBlockClauseToInvoke clauseToInvoke, Boolean createLocalScope, Dictionary`2 functionsToDefine, List`1 variablesToDefine, ErrorHandlingBehavior errorHandlingBehavior, Object dollarUnder, Object input, Object scriptThis, Pipe outputPipe, InvocationInfo invocationInfo, Object[] args) in /root/parts/powershell/build/src/System.Management.Automation/engine/runtime/CompiledScriptBlock.cs:line 1211
   at System.Management.Automation.ScriptBlock.InvokeWithPipe(Boolean useLocalScope, ErrorHandlingBehavior errorHandlingBehavior, Object dollarUnder, Object input, Object scriptThis, Pipe outputPipe, InvocationInfo invocationInfo, Boolean propagateAllExceptionsToTop, List`1 variablesToDefine, Dictionary`2 functionsToDefine, Object[] args) in /root/parts/powershell/build/src/System.Management.Automation/engine/lang/scriptblock.cs:line 980
   at Microsoft.PowerShell.Commands.ForEachObjectCommand.ProcessScriptBlockParameterSet() in /root/parts/powershell/build/src/System.Management.Automation/engine/InternalCommands.cs:line 921
   at System.Management.Automation.CommandProcessor.ProcessRecord() in /root/parts/powershell/build/src/System.Management.Automation/engine/CommandProcessor.cs:line 313
Disconnected from vCenter
PS /home/holuser/Desktop/code> 

