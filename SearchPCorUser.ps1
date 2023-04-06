function Search-CompUser {
    param(
    [parameter(Mandatory=$true)]
    $ComputerName
    )
    if($ComputerName){
        $search = Get-ADComputer -Identity $ComputerName -Properties Name, ManagedBy, IpV4address `
            | select Name, IpV4address, @{Name="ManagedBy";Expression={$_.ManagedBy.split(',')[0].replace("CN=",'')}}
            return $search
            }
    else {
        return Write-Warning -Message "Укажите  IP, Имя Компьютера или ФИО пользователя из AD!!!"
    }
}

function Search-Property {
param(
   [parameter(ValueFromPipeline)][psobject[]] $object, 
   [string] $pattern = ".", 
   [switch] $SearchInPropertyNames, 
   [switch] $ExcludeValues, 
   [switch] $LiteralSearch, 
   [string[]] $Property = "*", 
   [string[]] $ExcludeProperty 
) 
begin{
   if($LiteralSearch -and $pattern -ne "."){
      $pattern = [regex]::Escape($pattern) 
   } 
} 
process{
   foreach($o in $object){ 
      $o.psobject.properties | 
         Where-Object { 
            $propname = $_.name 
            $_.membertype -ne 'AliasProperty' -and 
            ( 
               $(if(!$ExcludeValues){$_.value -match $pattern}) -or 
               $(if($SearchInPropertyNames){$_.name -match $pattern}) 
            ) -and 
            !($ExcludeProperty | Where-Object {$propname -like $_}) -and 
            ($Property | Where-Object {$propname -like $_}) 
         } | Select-Object -Property @{n = "Object"; e = {$o.tostring()}}, Name, Value 
   } 
} 
}

#####################
Import-Module ActiveDirectory
Add-Type -assembly System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Write-Warning -Message "Убедитесь что у вас установлены средства управления RSAT!"

$comps = Get-ADComputer -Filter * -Properties Name, IPV4Address, Managedby #| Select Name, DistinguishedName, ManagedBy, IPv4Address
$users = Get-ADUser -Filter * -Properties Name, Samaccountname

$window_form = New-Object System.Windows.Forms.Form
$window_form.Text ='Поиск пользователя с данными IP и именем компа'
$window_form.Width = 500
$window_form.Height = 200
$window_form.AutoSize = $true
$window_form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog


$FormLabel1 = New-Object System.Windows.Forms.Label
$FormLabel1.Text = "Впишите имя компьютера или IP или имя компьютера"
$FormLabel1.Location = New-Object System.Drawing.Point(5,10)
$FormLabel1.AutoSize = $true
$window_form.Controls.Add($FormLabel1)

$FormLabel2 = New-Object System.Windows.Forms.Label
$FormLabel2.Text = "Необходимо указать только одно из выше перечисленных"
$FormLabel2.Location = New-Object System.Drawing.Point(5,25)
$FormLabel2.AutoSize = $true
$window_form.Controls.Add($FormLabel2)

#####################

$FormLabel3 = New-Object System.Windows.Forms.Label
$FormLabel3.Text = "Результат поиска: "
$FormLabel3.Location = New-Object System.Drawing.Point(5,70)
$FormLabel3.AutoSize = $true
$window_form.Controls.Add($FormLabel3)




#####################
$TextBox = New-Object System.Windows.Forms.TextBox
$TextBox.Width = 390
$TextBox.Location  = New-Object System.Drawing.Point(5,45)
$TextBox.Text 
$window_form.Controls.Add($TextBox)
$window_form.Add_Shown({$TextBox.Select()})

$TextBox1 = New-Object System.Windows.Forms.RichTextBox 
$TextBox1.ReadOnly = $true 
$TextBox1.Multiline = $true  
$TextBox1.Width = 390  
$TextBox1.Height = 300
$TextBox1.Multiline = $true
$TextBox1.Scrollbars = "Vertical"
$TextBox1.Refresh()
$TextBox1.ScrollToCaret()
$TextBox1.ToString()
$TextBox1.Location = New-Object System.Drawing.Point(5,90)
$window_form.Controls.Add($TextBox1)
$window_form.Add_Shown({$TextBox1.Select()})

#####################
$FormButton = New-Object System.Windows.Forms.Button
$FormButton.Location = New-Object System.Drawing.Size(400,45)
$FormButton.Size = New-Object System.Drawing.Size(100,25)
$FormButton.Text = "Тыкныте"
$window_form.Controls.Add($FormButton)
$FormButton.Add_Click({
try{
$computernames = (($comps | Search-Property -pattern $TextBox.Text -ExcludeProperty DistinguishedName, DNSHostName, SamAccountName).Object.split(',') `
| ? {$_ -like "CN=*"}).replace('CN=','')
}
Catch [System.Management.Automation.RuntimeException]{
$TextBox1.Appendtext("Нет информации о $($TextBox.Text.ToString())!"  + [Environment]::NewLine)
$TextBox1.Appendtext("------------------------------------------------------------`r`n")
}
foreach($computername in $computernames){
$info = Search-CompUser -ComputerName $computername `
| select Name, IPV4Address, Managedby, @{Name="Login";Expression={"$(if($_.Managedby -ne $null){($users `
| ? name -Like "*$($_.Managedby)*").SamAccountName}else{return $null})"}}
$TextBox1.Appendtext("Имя компьютера: " + $($info.Name.ToString() + [Environment]::NewLine))
$TextBox1.Appendtext("IP-адрес компьютера: " + $($info.IPV4Address.ToString() + [Environment]::NewLine))
try{
$TextBox1.Appendtext("Предпологаемый владелец: " + $($info.Managedby.ToString() + [Environment]::NewLine ))
}
catch [System.Management.Automation.RuntimeException]{
$TextBox1.Appendtext("Предпологаемый владелец не определен! "  + [Environment]::NewLine)
}
try{
$TextBox1.Appendtext("Login: " + $($info.Login.ToString() + [Environment]::NewLine))
}
catch [System.Management.Automation.RuntimeException]{
$TextBox1.Appendtext("Login не определен!"  + [Environment]::NewLine)
}
$TextBox1.Appendtext("------------------------------------------------------------`r`n")

        }
    }
)

$FormButton2 = New-Object System.Windows.Forms.Button
$FormButton2.Location = New-Object System.Drawing.Size(400,70)
$FormButton2.Size = New-Object System.Drawing.Size(100,25)
$FormButton2.Text = "Очистить окно"
$FormButton2.Add_Click({$TextBox1.Text = ''})
$window_form.Controls.Add($FormButton2)

$FormButton3 = New-Object System.Windows.Forms.Button
$FormButton3.Location = New-Object System.Drawing.Size(400,95)
$FormButton3.Size = New-Object System.Drawing.Size(100,25)
$FormButton3.Text = "Закрыть"
$FormButton3.Add_Click({$window_form.Close()})
$window_form.Controls.Add($FormButton3)

####################
[void]$window_form.ShowDialog()


