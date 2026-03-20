# 1. 權限檢查與自動提升 (UAC)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "正在請求管理員權限以停止服務..." -ForegroundColor Yellow
    # 透過 -Verb RunAs 重新以系統管理員身分呼叫自己
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  正在停止 AFS AI Hub 所有背景服務..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 停止 Java 程序 (Keycloak, API Relay)
Write-Host "停止 Java 服務..."
Stop-Process -Name "java" -Force -ErrorAction SilentlyContinue

# 停止 Node 程序 (AI Portal)
Write-Host "停止 Node 服務..."
Stop-Process -Name "node" -Force -ErrorAction SilentlyContinue

# 停止 PostgreSQL 程序
Write-Host "停止 PostgreSQL 服務..."
Stop-Process -Name "postgres" -Force -ErrorAction SilentlyContinue

Write-Host "所有服務已順利終止！" -ForegroundColor Green
Start-Sleep -Seconds 3