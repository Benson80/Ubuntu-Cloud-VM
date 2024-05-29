# 获取当前用户的 known_hosts 文件路径
$knownHostsPath = "$env:USERPROFILE\.ssh\known_hosts"

# 检查并删除 known_hosts 文件
if (Test-Path $knownHostsPath) {
    Remove-Item $knownHostsPath -Force
    Write-Host "已删除 known_hosts 文件：$knownHostsPath"
} else {
    Write-Host "known_hosts 文件不存在：$knownHostsPath"
}
