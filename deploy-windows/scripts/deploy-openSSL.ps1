# ==========================================
# deploy-openSSL.ps1 (純淨無亂碼版)
# ==========================================

# ==========================================
# 0. 檢查是否已經安裝過 OpenSSL
# ==========================================
$existingOpenSSL = Get-Command openssl -ErrorAction SilentlyContinue
if ($existingOpenSSL) {
    Write-Host "OpenSSL 已經安裝且配置正確，跳過安裝步驟！" -ForegroundColor Green
    & openssl version
    return  # 直接退出這支腳本，回到主程式
}
$SCRIPT_DIR = $PSScriptRoot
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$msiUrl = "https://slproweb.com/download/Win64OpenSSL_Light-3_6_1.msi"
$msiFile = Join-Path $PROJECT_ROOT "packages\OpenSSL_Light_3_6_1.msi"

Write-Host "正在檢查與下載 OpenSSL 安裝檔..." -ForegroundColor Yellow
try {
if (-not (Test-Path $msiFile)) {
Invoke-WebRequest -Uri $msiUrl -OutFile $msiFile -ErrorAction Stop
}
} catch {
throw "下載失敗，請檢查網路連線。"
}

Write-Host "正在清理系統可能殘留的舊版登錄檔..." -ForegroundColor Gray
Start-Process msiexec.exe -ArgumentList "/x `"$msiFile`" /quiet /norestart" -Wait -PassThru | Out-Null
Start-Sleep -Seconds 2

Write-Host "正在安裝 OpenSSL 3.6.1 (需管理員權限)..." -ForegroundColor Yellow
$installProcess = Start-Process msiexec.exe -ArgumentList "/i `"$msiFile`" /quiet /norestart" -Wait -PassThru
Start-Sleep -Seconds 3

if ($installProcess.ExitCode -ne 0) {
throw "安裝失敗，錯誤代碼: $($installProcess.ExitCode)。"
}
Write-Host "安裝成功！" -ForegroundColor Green

$possiblePaths = @(
"C:\Program Files\OpenSSL-Win64",
"C:\Program Files\OpenSSL",
"C:\Program Files (x86)\OpenSSL-Win64"
)

$installPath = $null
foreach ($p in $possiblePaths) {
if (Test-Path "$p\bin\openssl.exe") {
$installPath = $p
break
}
}

if (-not $installPath) {
throw "找不到 OpenSSL 實際安裝路徑！"
}

$binPath = Join-Path $installPath "bin"
$env:PATH = "$binPath;" + $env:PATH
$configFile = Join-Path $binPath "openssl.cfg"
$env:OPENSSL_CONF = $configFile

Write-Host "目前 OpenSSL 位於: $binPath" -ForegroundColor White
& "$binPath\openssl.exe" version

$oldPath = [Environment]::GetEnvironmentVariable("Path", "User")
$needAdd = $true

if ($oldPath -ne $null) {
if ($oldPath -match [regex]::Escape($binPath)) {
$needAdd = $false
}
}

if ($needAdd -eq $true) {
$newPath = $oldPath + ";" + $binPath
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")
Write-Host "已將 OpenSSL 加入使用者 PATH" -ForegroundColor Green
}

[Environment]::SetEnvironmentVariable("OPENSSL_CONF", $configFile, "User")
Write-Host "已設置使用者 OPENSSL_CONF 變數" -ForegroundColor Green

# ==========================================
# 新增：清理下載的 MSI 安裝檔
# ==========================================
<#
if (Test-Path $msiFile) {
    Write-Host "正在清理安裝檔 ($msiFile)..." -ForegroundColor Gray
    Remove-Item -Path $msiFile -Force -ErrorAction SilentlyContinue
    Write-Host "安裝檔清理完成！" -ForegroundColor Green
}#>

Write-Host "OpenSSL 部署完成！" -ForegroundColor Cyan