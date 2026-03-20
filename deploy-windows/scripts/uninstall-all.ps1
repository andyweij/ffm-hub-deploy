# ========================================================
#   AFS AI Hub Windows 一鍵清理/解除安裝腳本 (uninstall-all.ps1)
# ========================================================

# 新增接收參數，讓 Inno Setup 可以靜默呼叫
param(
    [switch]$Quiet
)

# 1. 權限檢查與自動提升
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "正在請求管理員權限以執行解除安裝..." -ForegroundColor Yellow
    # 傳遞 $Quiet 參數確保提權後行為一致
    $args = if ($Quiet) { "-Quiet" } else { "" }
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $args" -Verb RunAs
    exit
}

$SCRIPT_DIR = $PSScriptRoot
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR

# 2. 二次確認 (如果「非」靜默模式，才跳出確認)
if (-not $Quiet) {
    Write-Host "=================================================" -ForegroundColor Red
    Write-Host "  警告：即將執行 AFS AI Hub 完整清理與解除安裝" -ForegroundColor Red
    Write-Host "  這將會刪除所有日誌、憑證、資料庫資料以及下載的模型！" -ForegroundColor Red
    Write-Host "=================================================" -ForegroundColor Red
    Write-Host ""

    $Confirm = Read-Host "您確定要繼續嗎？請輸入 'YES' 以繼續執行 (其他任意鍵取消)"
    if ($Confirm -ne "YES") {
        Write-Host "取消解安裝程序。" -ForegroundColor Yellow
        exit 0 
    }
}
Write-Host ""
Write-Host "[1/4] 正在終止所有相關背景服務..." -ForegroundColor Yellow

# 呼叫現有的 stop-all.ps1，或直接在這裡停止
$ProcessNames = @("java", "node", "postgres")
foreach ($proc in $ProcessNames) {
    Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
    Write-Host "  - 已嘗試停止 $proc 程序" -ForegroundColor Gray
}
# 給予一點時間讓作業系統釋放檔案鎖定
Start-Sleep -Seconds 3 
# =========================================================
# 改為呼叫獨立腳本
# =========================================================
Write-Host ""
Write-Host "[2/4] 呼叫 OpenSSL 解除安裝模組..." -ForegroundColor Yellow

$OpenSSLScript = Join-Path $SCRIPT_DIR "uninstall-openSSL.ps1"
if (Test-Path $OpenSSLScript) {
    # 根據主腳本是否有帶入 -Quiet，決定是否靜默呼叫子腳本
    if ($Quiet) {
        & $OpenSSLScript -Quiet
    } else {
        & $OpenSSLScript
    }
} else {
    Write-Host "  - 找不到 $OpenSSLScript，略過獨立解除安裝程序。" -ForegroundColor Red
}
# =========================================================

Write-Host ""
Write-Host "[3/4] 正在清理外部模型與工作目錄..." -ForegroundColor Yellow

# 動態取得當前使用者的「我的文件」路徑 (例如: C:\Users\XXX\Documents)
$DocsPath = [Environment]::GetFolderPath("MyDocuments")
$WorkspacePath = Join-Path $DocsPath "workspace\TWS"

if (Test-Path $WorkspacePath) {
    try {
        Remove-Item -Path $WorkspacePath -Recurse -Force -ErrorAction Stop
        Write-Host "  - 成功刪除工作目錄: $WorkspacePath" -ForegroundColor Green
    } catch {
        Write-Host "  - 刪除失敗: $WorkspacePath (可能檔案仍被佔用，請稍後手動刪除)" -ForegroundColor Red
    }
} else {
    Write-Host "  - 略過 (不存在): $WorkspacePath" -ForegroundColor Gray
}


Write-Host ""
Write-Host "[4/4] 正在清理專案根目錄 ($PROJECT_ROOT)..." -ForegroundColor Yellow

# 【關鍵技巧】將 PowerShell 的工作目錄切換到系統的 Temp 目錄，徹底解除對安裝資料夾的鎖定
Set-Location $env:TEMP
Start-Sleep -Seconds 2 # 給系統一點時間釋放資源

try {
    # 嘗試強制刪除整個根目錄 (除了正在執行的腳本本身可能砍不掉，其他都會被清空)
    Remove-Item -Path $PROJECT_ROOT\* -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  - 已清空專案根目錄下的所有服務與資料" -ForegroundColor Green
} catch {
    Write-Host "  - 部分檔案清理中，將由反安裝程式 (Inno Setup) 進行最終收尾" -ForegroundColor Gray
}


Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "  AFS AI Hub 解除安裝/清理流程已完成！" -ForegroundColor Green
Write-Host "  (目前的 cmd/powershell 視窗環境變數可能需重開才會刷新)" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""
Start-Sleep -Seconds 5