#####################################
Import-Module ActiveDirectory
Import-Module ThreadJob
function Get-CompUser($compname){
        $copminfo = Get-ADComputer $compname -Properties * -ErrorAction SilentlyContinue
    if (!($copminfo.ManagedBy))
        {
            try{
                $getuser = (Get-WmiObject -ComputerName $compname -Class WIN32_COMPUTERSYSTEM -ErrorAction SilentlyContinue).UserName
                Set-ADComputer $compname -ManagedBy $getuser.split('\')[1]
                Write-Output the PC $compname.ToUpper() is managed by $getuser and IP is $copminfo.IPv4Address
            }
            catch [System.Runtime.InteropServices.COMException]{
                $getuser = Invoke-Command $compname -ScriptBlock {(Get-WmiObject -Class WIN32_COMPUTERSYSTEM -ErrorAction SilentlyContinue).username}
                Write-Output the PC $compname.ToUpper() is managed by $getuser and IP is $copminfo.IPv4Address
            }
            catch [System.Management.Automation.Remoting.PSRemotingTransportException]{
                Write-Warning "WinRM is not availibleblya on $($compname)"
            }
            catch [System.Management.Automation.RuntimeException]{
                Write-Warning "RPC and WinRM is not availibleblya on $($compname)"
            }
        }
    else
        {
            Write-Output The $copminfo.ManagedBy.split(',')[0].replace("CN=",'') is loged on pc $compname.ToUpper() and IP is $copminfo.IPv4Address
        }
    }


######################################
$complist = Get-ADComputer -Filter 'Enabled -EQ $True' -Properties Name, OperatingSystem -SearchBase $(((Get-ADUser $env:USERNAME).DistinguishedName.split(',') `
| select -Last 2) -join ',')  `
| ? OperatingSystem -Like "*Windows 1*"
$jobs = @()

foreach ($comp in $complist.name){
    $jobs += Start-ThreadJob -ScriptBlock {

    function Get-CompUser($compname){
        $copminfo = Get-ADComputer $compname -Properties * -ErrorAction SilentlyContinue
    if (!($copminfo.ManagedBy))
        {
            try{
                $getuser = (Get-WmiObject -ComputerName $compname -Class WIN32_COMPUTERSYSTEM -ErrorAction SilentlyContinue).UserName
                Set-ADComputer $compname -ManagedBy $getuser.split('\')[1]
                Write-Host the PC $compname.ToUpper() is managed by: $getuser and IP is: $copminfo.IPv4Address
            }
            catch [System.Runtime.InteropServices.COMException]{
                $getuser = Invoke-Command $compname -ScriptBlock {
                (Get-WmiObject -Class WIN32_COMPUTERSYSTEM -ErrorAction SilentlyContinue).username
                }
                Write-Host the PC $compname.ToUpper() is managed by: $getuser and IP is: $copminfo.IPv4Address
            }
            catch [System.Management.Automation.Remoting.PSRemotingTransportException]{
                Write-Warning "WinRM is not availibleblya on: $($compname)"
            }
            catch [System.Management.Automation.RuntimeException]{
                Write-Warning "RPC and WinRM is not availibleblya on: $($compname)"
            }
        }
    else
        {
            Write-Host The $copminfo.ManagedBy.split(',')[0].replace("CN=",'') is loged on pc $compname.ToUpper() and IP is $copminfo.IPv4Address
        }
    }

    Get-CompUser $Using:comp
    }
}

Write-Host "Job started..."
Wait-Job -Job $jobs
foreach ($job in $jobs) {
    Receive-Job -Job $job | Out-GridView
}
pause
