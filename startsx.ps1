param (
    [Alias("n")]
    [string]$name = "",

    [Alias("c")]
    [int]$cpus = 1,

    [Alias("m")]
    [int]$mem = 1,

    [Alias("d")]
    [int]$disk = 5
)

# 检查是否以管理员身份运行
$isAdmin = ([System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "请以管理员身份运行此脚本。"
    Exit
}

# 参数有效性检查
if (-not $name) {
    Write-Host "用法: startsx -n <虚拟机名称> [-c <CPU核心数>] [-m <内存大小>] [-d <硬盘大小>]"
    Write-Host "说明: 启动虚拟机并指定其名称以及可选的CPU核心数、内存大小和硬盘大小。"
    Write-Host ""
    Write-Host "参数:"
    Write-Host "  -n, --name      虚拟机名称。"
    Write-Host "  -c, --cpus      CPU核心数。默认值为1。"
    Write-Host "  -m, --mem       内存大小（以 GB 为单位）。默认值为1。"
    Write-Host "  -d, --disk      硬盘大小（以 GB 为单位）。默认值为5。"
    Write-Host ""
    Write-Host "示例:"
    Write-Host "  startsx -n vm1 -c 4 -m 4 -d 100"
    exit
}

if ($cpus -le 0 -or $mem -le 0 -or $disk -le 0) {
    Write-Host "CPU核心数、内存大小和硬盘大小必须是正整数。"
    exit
}

# 确保加载 Hyper-V 模块
if (-not (Get-Module -Name Hyper-V)) {
    Import-Module Hyper-V
}

# 将内存和磁盘大小从GB转换为字节
$MemoryBytes = $mem * 1GB
$DiskBytes = $disk * 1GB

# 定义路径
$vmPath = "F:\Hyper-V\$name"
$vhdxPath = "$vmPath\$name.vhdx"
$imgPath = "F:\Ubuntu\noble-server-cloudimg-amd64.vhdx"
$seedISOPath = "F:\Ubuntu\seed.iso"

# 如果虚拟机已存在，删除它
$vm = Get-VM -Name $name -ErrorAction SilentlyContinue
if ($vm) {
    Write-Host "虚拟机 $name 已存在，正在删除..."
    Stop-VM -Name $name -Force -ErrorAction SilentlyContinue
    Remove-VM -Name $name -Force -ErrorAction SilentlyContinue

    # 删除虚拟机文件夹
    Start-Sleep -Seconds 5 # 确保虚拟机已停止并删除
    Remove-Item -Path $vmPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "已删除现有的虚拟机 $name。"
}

# 如果虚拟机文件夹已存在，先删除它
if (Test-Path $vmPath) {
    Write-Host "虚拟机文件夹 $vmPath 已存在，正在删除..."
    Remove-Item -Path $vmPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "已删除现有的虚拟机文件夹 $vmPath。"
}

# 创建虚拟机文件夹
New-Item -ItemType Directory -Path $vmPath -ErrorAction SilentlyContinue

# 复制 .vhdx 文件到目标路径
Copy-Item -Path $imgPath -Destination $vhdxPath

# 扩展 .vhdx 文件到指定大小
Write-Host "正在扩展 .vhdx 文件到 $disk GB..."
Resize-VHD -Path $vhdxPath -SizeBytes $DiskBytes
Write-Host "扩展完成：$vhdxPath"

# 创建虚拟机
New-VM -Name $name -MemoryStartupBytes $MemoryBytes -Path $vmPath

# 设置 CPU 核心数量
Set-VMProcessor -VMName $name -Count $cpus

# 附加扩展后的虚拟硬盘到虚拟机
Add-VMHardDiskDrive -VMName $name -Path $vhdxPath

# 附加 Seed ISO 文件
Add-VMDvdDrive -VMName $name -Path $seedISOPath

# 删除第一个网络适配器（如果存在）
$existingAdapters = Get-VMNetworkAdapter -VMName $name
if ($existingAdapters.Count -gt 0) {
    Remove-VMNetworkAdapter -VMName $name -Name $existingAdapters[0].Name
}

# 添加新的网络适配器并连接到 Default Switch
Add-VMNetworkAdapter -VMName $name -SwitchName "Default Switch"

# 定义虚拟网络适配器名称和IP地址
$adapterName = "vEthernet (MyPrivateNet)"
$ipAddress = "192.168.218.1"
$prefixLength = "24"

# 创建虚拟交换机（如果不存在）
if (-not (Get-NetAdapter -Name $adapterName -ErrorAction SilentlyContinue)) {
    New-VMSwitch -Name "MyPrivateNet" -SwitchType Private | Out-Null
}

# 删除现有的IP地址
$existingIP = Get-NetIPAddress -InterfaceAlias $adapterName -ErrorAction SilentlyContinue
if ($existingIP) {
    Remove-NetIPAddress -InterfaceAlias $adapterName -Confirm:$false
}

# 设置新的IP地址
New-NetIPAddress -InterfaceAlias $adapterName -IPAddress $ipAddress -PrefixLength $prefixLength -ErrorAction SilentlyContinue > $null

# 检查是否已存在同名网络适配器
$existingAdapter = Get-VMNetworkAdapter -VMName $name -Name $adapterName -ErrorAction SilentlyContinue
if (-not $existingAdapter) {
    # 添加第二个网络适配器并连接到 MyPrivateNet
    Add-VMNetworkAdapter -VMName $name -SwitchName "MyPrivateNet"
} else {
    Write-Host "虚拟机 $name 已存在名为 '$adapterName' 的网络适配器。"
}

# 启动虚拟机
Start-VM -Name $name

# 记录日志
$logFilePath = "F:\Hyper-V\$name\startsx.log"
$logContent = @"
虚拟机 $name 已创建并启动，CPU 核心：$cpus，内存：${mem}GB，虚拟硬盘：${disk}GB
网络适配器名称：$adapterName
IP 地址：$ipAddress
"@
$logContent | Out-File -FilePath $logFilePath -Append

Write-Host "虚拟机 $name 已创建并启动，CPU 核心：$cpus，内存：${mem}GB，虚拟硬盘：${disk}GB"
Write-Host "网络适配器名称：$adapterName"
Write-Host "IP 地址：$ipAddress"
