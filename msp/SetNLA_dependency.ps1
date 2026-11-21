Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
$serviceName = "NlaSvc"
$svcDepends = "DNS"
$dependOnReg = "DependOnService"
try
{
$service = Get-Service -Name $serviceName
if ($service)
{
  $currentDependencies = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName" -Name "DependOnService").$dependOnReg
  if ($currentDependencies -notcontains $svcDepends)
  {
    $updateDependencies = @($currentDependencies) + $svcDepends
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName" -Name $dependOnReg -Value $updateDependencies -type MultiString
    #Tell me it worked
    #Write-Host "dependency: $svcDepends added."
   }
   else
   {
     #Write-Host "dependency already exists"
   }
}
else
{
  #Write-Host "Service Name not found."
}
}
catch
{
    write-host $Error.ToString()
#Write-Host "Error"
}

