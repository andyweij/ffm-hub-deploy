# ========================================================
# get-ip.ps1
# 功能：動態偵測本機對外 IP，若失敗則強制手動輸入
# 回傳：最終決定的 IP 字串
# ========================================================

$AutoIP = $null

# 1. 嘗試動態偵測 (加上 try-catch 防止某些特殊網卡配置導致指令報錯)
try {
    $AutoIP = (Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -eq "Up" }).IPv4Address.IPAddress | Select-Object -First 1
} catch {
    # 忽略錯誤，交給下方的手動輸入邏輯處理
}

$FinalIP = ""

# 2. 判斷偵測結果
if ($AutoIP) {
    # 情況 A：有抓到 IP，提供預設值讓使用者直接 Enter
    Write-Host ">> 系統偵測到本機目前的對外 IP 為: $AutoIP" -ForegroundColor Yellow
    $UserInput = Read-Host "請輸入對外 IP 位址 (直接按 Enter 將預設使用 $AutoIP)"
    
    if ([string]::IsNullOrWhiteSpace($UserInput)) {
        $FinalIP = $AutoIP
        Write-Host "  -> 已自動套用 IP: $FinalIP" -ForegroundColor Green
    } else {
        $FinalIP = $UserInput
        Write-Host "  -> 已手動設定 IP: $FinalIP" -ForegroundColor Green
    }
} else {
    # 情況 B：完全抓不到 IP (無網路、無預設閘道，或指令失效)
    Write-Host ">> 無法自動偵測對外 IP (可能無網路連線或處於封閉虛擬網段)。" -ForegroundColor Yellow
    
    # 使用 while 迴圈，強制要求使用者一定要輸入東西才能繼續
    while ([string]::IsNullOrWhiteSpace($FinalIP)) {
        $FinalIP = Read-Host "請手動輸入本機 IP 位址 (例如: 192.168.1.100)"
        
        if ([string]::IsNullOrWhiteSpace($FinalIP)) {
            Write-Host "  [錯誤] IP 位址不能為空，請重新輸入！" -ForegroundColor Red
        }
    }
    Write-Host "  -> 已手動設定 IP: $FinalIP" -ForegroundColor Green
}

# 3. 將最終決定的 IP 拋出給呼叫它的母腳本 (例如 deploy-all.ps1)
Write-Output $FinalIP