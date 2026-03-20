# ========================================================
#   uninstall-openSSL.ps1
# ========================================================
param(
    [switch]$Quiet
)

# 1. 權限檢查與自動提升 (UAC)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "正在請求管理員權限以解除安裝 OpenSSL..." -ForegroundColor Yellow
    $args = if ($Quiet) { "-Quiet" } else { "" }
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $args" -Verb RunAs
    exit
}

$SCRIPT_DIR = $PSScriptRoot
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  處理並解除安裝 OpenSSL" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

if ($Quiet) {
    $AskOpenSSL = "Y"
} else {
    $AskOpenSSL = Read-Host "是否要徹底解除安裝 OpenSSL 主程式與環境變數 (若其他軟體有依賴請選 N)? (Y/N)"
}

if ($AskOpenSSL -match "^[Yy]$") {
    Write-Host "  - 正在尋找 OpenSSL 安裝紀錄..." -ForegroundColor Gray
    
    $OpenSSLApp = $null

    $UninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($path in $UninstallPaths) {
        if (Test-Path $path) {
            $subkeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
            foreach ($subkey in $subkeys) {
                $prop = Get-ItemProperty -Path $subkey.PSPath -ErrorAction SilentlyContinue
                if ($null -ne $prop.DisplayName -and $prop.DisplayName -match "OpenSSL") {
                    $OpenSSLApp = $prop
                    break
                }
            }
        }
        if ($OpenSSLApp) { break }
    }

    if ($OpenSSLApp) {
        Write-Host "  - 找到 $($OpenSSLApp.DisplayName)，準備靜默解除安裝..." -ForegroundColor Cyan
        
        if ($OpenSSLApp.PSChildName -match "^\{.*\}$") {
            $ProductCode = $OpenSSLApp.PSChildName
            $Process = Start-Process msiexec.exe -ArgumentList "/x `"$ProductCode`" /quiet /norestart" -Wait -PassThru
            
            if ($Process.ExitCode -eq 0 -or $Process.ExitCode -eq 3010) {
                Write-Host "  - OpenSSL 主程式解除安裝完成！" -ForegroundColor Green
            } else {
                Write-Host "  - 警告: OpenSSL 解除安裝結束，回傳代碼 $($Process.ExitCode)。" -ForegroundColor Yellow
            }
        } else {
            $UninstallCmd = $OpenSSLApp.UninstallString -replace "/I", "/X" -replace "/i", "/x"
            $UninstallCmd += " /quiet /norestart"
            Start-Process cmd.exe -ArgumentList "/c $UninstallCmd" -Wait -NoNewWindow
            Write-Host "  - OpenSSL 主程式解除安裝完成！" -ForegroundColor Green
        }
    } else {
        $MsiPath = Join-Path $PROJECT_ROOT "packages\OpenSSL_Light_3_6_1.msi"
        if (Test-Path $MsiPath) {
            Write-Host "  - 登錄檔未尋獲，但發現原始安裝檔，將透過該檔案執行解除安裝..." -ForegroundColor Cyan
            $Process = Start-Process msiexec.exe -ArgumentList "/x `"$MsiPath`" /quiet /norestart" -Wait -PassThru
            Write-Host "  - OpenSSL 主程式已透過原始檔案解除安裝！" -ForegroundColor Green
        } else {
            Write-Host "  - 系統中未偵測到已安裝的 OpenSSL，或已經被移除。" -ForegroundColor Gray
        }
    }

    # 清理環境變數
    $sslConf = [Environment]::GetEnvironmentVariable("OPENSSL_CONF", "User")
    if ($sslConf) {
        [Environment]::SetEnvironmentVariable("OPENSSL_CONF", $null, "User")
        Write-Host "  - 已移除使用者環境變數: OPENSSL_CONF" -ForegroundColor Green
    }

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -match "OpenSSL") {
        $pathArray = $userPath -split ";"
        $newPathArray = $pathArray | Where-Object { $_ -notmatch "OpenSSL" }
        $newPath = $newPathArray -join ";"
        
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Host "  - 已將 OpenSSL 自使用者的 PATH 變數中移除" -ForegroundColor Green
    } else {
        Write-Host "  - 使用者的 PATH 變數中未發現 OpenSSL 路徑" -ForegroundColor Gray
    }
} else {
    Write-Host "  - 略過 OpenSSL 解除安裝。" -ForegroundColor Gray
}