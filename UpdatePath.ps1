# 获取系统环境变量Path
$path = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)

# 需要添加的路径
$newPath = "F:\Ubuntu"

# 检查Path中是否包含该路径
if ($path -notlike "*$newPath*") {
    # 如果不包含，则添加该路径
    $updatedPath = "$path;$newPath"
    [System.Environment]::SetEnvironmentVariable("Path", $updatedPath, [System.EnvironmentVariableTarget]::Machine)
    Write-Output "Path has been updated to include $newPath"
} else {
    Write-Output "Path already contains $newPath"
}
