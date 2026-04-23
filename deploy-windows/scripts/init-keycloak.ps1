# ========================================
#   AFS AI Hub Keycloak 初始化腳本
#   Windows 環境 (非 Docker 部署)
#   (純淨版：完全依賴 config.json 讀取環境變數)
# ========================================

# ========== 1. 基礎路徑配置 ==========
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$LOG_DIR = Join-Path $PROJECT_ROOT "logs"
$LOG_FILE = Join-Path $LOG_DIR "init-keycloak.log"
$CONFIG_DIR = Join-Path $PROJECT_ROOT "config"

# ========== 2. 載入 config.json (單一設定來源) ==========
$CONFIG_PATH = Join-Path $PROJECT_ROOT "config.json"
if (-not (Test-Path $CONFIG_PATH)) {
    Write-Host "[錯誤] 找不到 config.json，請確認設定檔是否存在！" -ForegroundColor Red
    exit 1
}
$Config = Get-Content -Path $CONFIG_PATH -Raw | ConvertFrom-Json

# 從 Config 提取變數
$VM_IP             = $Config.Global.VM_IP
$KEYCLOAK_PORT     = $Config.Keycloak.PORT
$REALM_NAME        = $Config.Keycloak.REALM_NAME
$ADMIN_USERNAME    = $Config.Keycloak.ADMIN_USERNAME
$ADMIN_PASSWORD    = $Config.Keycloak.ADMIN_PASSWORD
$NEW_USER          = $Config.Keycloak.APP_USERNAME
$NEW_USER_PASSWORD = $Config.Keycloak.APP_PASSWORD
$CLIENT_ID         = $Config.Keycloak.CLIENT_ID

$JSON_FILE         = "afs-ai-hub.json"
$FULL_JSON_PATH    = Join-Path $CONFIG_DIR $JSON_FILE

$KEYCLOAK_URL        = "https://${VM_IP}:${KEYCLOAK_PORT}"
$KEYCLOAK_HEALTH_URL = "https://${VM_IP}:9000"
$ROLE_NAME           = "admin"
$CLIENT_ID_GRAFANA   = "grafana-oauth"

# ========== 建立日誌目錄 ==========
if (-not (Test-Path $LOG_DIR)) {
    New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null
}

# ========== 日誌函數 ==========
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    
    # 1. 輸出到畫面
    Write-Host $logMessage -ForegroundColor $Color

    # 2. 寫入檔案 (加入 Retry 防鎖定機制)
    $maxRetries = 5
    $retryCount = 0
    $written = $false

    while ($retryCount -lt $maxRetries -and -not $written) {
        try {
            # 這裡加上 -ErrorAction Stop，讓失敗時直接跳進 catch
            Add-Content -Path $LOG_FILE -Value $logMessage -ErrorAction Stop
            $written = $true
        } catch {
            $retryCount++
            # 遇到鎖定，暫停 200 毫秒後重試
            Start-Sleep -Milliseconds 200 
        }
    }
}

function Write-StepHeader {
    param([int]$Step, [int]$Total, [string]$Title)
    Write-Log ""
    Write-Log "[$Step/$Total] $Title" "Yellow"
    Write-Log ("-" * 50)
}

# ========== 忽略 SSL 憑證驗證 (自簽憑證) ==========
if (-not ([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type) {
    Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
}
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ========== 驗證參數 ==========
if ([string]::IsNullOrWhiteSpace($VM_IP)) {
    Write-Log "錯誤：VM_IP 不能為空 (請檢查 config.json)" "Red"
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AFS AI Hub Keycloak 初始化腳本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "Keycloak URL  : $KEYCLOAK_URL"
Write-Log "VM IP         : $VM_IP"
Write-Log "Realm         : $REALM_NAME"
Write-Log "新用戶        : $NEW_USER"
Write-Log "日誌檔案      : $LOG_FILE"

$TOTAL_STEPS = 8
$LOCAL_VM_IP = "https://${VM_IP}/*"

# ========== 步驟 1: 等待 Keycloak 健康檢查 ==========
Write-StepHeader -Step 1 -Total $TOTAL_STEPS -Title "等待 Keycloak 健康檢查"

$MAX_WAIT = 120
$WAIT_COUNT = 0

while ($true) {
    try {
        $healthResponse = Invoke-WebRequest -Uri "${KEYCLOAK_HEALTH_URL}/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($healthResponse.StatusCode -eq 200) {
            Write-Log "Keycloak 健康檢查通過" "Green"
            break
        }
    } catch {
        Write-Log "Keycloak 尚未就緒，等待中... ($WAIT_COUNT/$MAX_WAIT 秒)"
    }

    Start-Sleep -Seconds 10
    $WAIT_COUNT += 10

    if ($WAIT_COUNT -ge $MAX_WAIT) {
        Write-Log "錯誤：Keycloak 健康檢查超時 (${MAX_WAIT}秒)" "Red"
        exit 1
    }
}

# ========== 步驟 2: 獲取管理員 Access Token ==========
Write-StepHeader -Step 2 -Total $TOTAL_STEPS -Title "獲取管理員 Access Token"

$MAX_TOKEN_RETRIES = 30
$TOKEN_RETRY_COUNT = 0
$ACCESS_TOKEN = $null

while ([string]::IsNullOrWhiteSpace($ACCESS_TOKEN)) {
    try {
        $tokenBody = @{
            client_id  = "admin-cli"
            username   = $ADMIN_USERNAME
            password   = $ADMIN_PASSWORD
            grant_type = "password"
        }

        $tokenResponse = Invoke-RestMethod `
            -Uri "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" `
            -Method Post -Body $tokenBody -ContentType "application/x-www-form-urlencoded"

        $ACCESS_TOKEN = $tokenResponse.access_token

        if (-not [string]::IsNullOrWhiteSpace($ACCESS_TOKEN)) {
            Write-Log "成功獲取 access token" "Green"
            break
        }
    } catch {
        Write-Log "獲取 token 失敗: $($_.Exception.Message)"
    }

    $TOKEN_RETRY_COUNT++
    Write-Log "獲取 token 失敗 (嘗試 $TOKEN_RETRY_COUNT/$MAX_TOKEN_RETRIES)，10 秒後重試..."

    if ($TOKEN_RETRY_COUNT -ge $MAX_TOKEN_RETRIES) {
        Write-Log "錯誤：獲取 access token 失敗，已達最大重試次數" "Red"
        exit 1
    }

    Start-Sleep -Seconds 10
}

$headers = @{
    "Authorization" = "Bearer $ACCESS_TOKEN"
    "Content-Type"  = "application/json"
}

# ========== 步驟 3: 匯入 Realm JSON 設定 ==========
Write-StepHeader -Step 3 -Total $TOTAL_STEPS -Title "匯入 Realm 設定 ($REALM_NAME)"

if (Test-Path $FULL_JSON_PATH) {
    try {
        Write-Log "正在讀取設定檔: $FULL_JSON_PATH"
        $realmJsonContent = Get-Content -Path $FULL_JSON_PATH -Raw -Encoding UTF8
        
        # 檢查 Realm 是否已經存在
        #$checkRealm = Invoke-RestMethod -Uri "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" -Method Get -Headers $headers -ErrorAction SilentlyContinue
        
        if ($null -ne $checkRealm) {
            Write-Log "Realm '$REALM_NAME' 已存在，跳過匯入步驟。" "Yellow"
        } else {
            Write-Log "正在匯入 Realm..."
            Invoke-RestMethod `
                -Uri "${KEYCLOAK_URL}/admin/realms" `
                -Method Post -Headers $headers -Body $realmJsonContent -ErrorAction Stop
            Write-Log "Realm 匯入成功" "Green"
        }
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 409) {
            Write-Log "偵測到 Realm '$REALM_NAME' 已存在 (409 Conflict)，跳過匯入並繼續執行。" "Yellow"
        } else {
            $errorMessage = $_.Exception.Message
            Write-Log "匯入 Realm 過程發生非預期錯誤: $errorMessage" "Yellow"
            Write-Log "嘗試繼續執行後續初始化步驟..." "Yellow"
        }
    }
} else {
    Write-Log "找不到 JSON 檔案: $FULL_JSON_PATH，請檢查路徑。" "Red"
    exit 1
}

# ========== 步驟 4: 創建新用戶並設置密碼 ==========
Write-StepHeader -Step 4 -Total $TOTAL_STEPS -Title "創建新用戶 $NEW_USER"

$userPayload = @{
    username        = $NEW_USER
    enabled         = $true
    requiredActions = @("terms_and_conditions")
} | ConvertTo-Json

try {
    Invoke-RestMethod `
        -Uri "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users" `
        -Method Post -Headers $headers -Body $userPayload
    Write-Log "用戶 $NEW_USER 創建成功" "Green"
} catch {
    if ($_.Exception.Response.StatusCode -eq 409) {
        Write-Log "用戶 $NEW_USER 已存在，跳過創建" "Yellow"
    } else {
        Write-Log "創建用戶失敗: $($_.Exception.Message)" "Red"
    }
}

# 獲取用戶 ID
Write-Log "獲取用戶 $NEW_USER 的 ID..."

try {
    $userResponse = Invoke-RestMethod `
        -Uri "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users?username=${NEW_USER}" `
        -Method Get -Headers $headers

    $USER_ID = $userResponse[0].id

    if ([string]::IsNullOrWhiteSpace($USER_ID)) {
        Write-Log "錯誤：無法獲取用戶 ID" "Red"
        exit 1
    }
    Write-Log "用戶 ID: $USER_ID" "Green"
} catch {
    Write-Log "錯誤：獲取用戶 ID 失敗: $($_.Exception.Message)" "Red"
    exit 1
}

# 設置用戶密碼
Write-Log "設置用戶 $NEW_USER 的密碼..."

$passwordPayload = @{
    type      = "password"
    value     = $NEW_USER_PASSWORD
    temporary = $false
} | ConvertTo-Json

try {
    Invoke-RestMethod `
        -Uri "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users/${USER_ID}/reset-password" `
        -Method Put -Headers $headers -Body $passwordPayload
    Write-Log "密碼設置成功" "Green"
} catch {
    Write-Log "設置密碼失敗: $($_.Exception.Message)" "Red"
}

# ========== 步驟 5: 映射 admin 角色到用戶 ==========
Write-StepHeader -Step 5 -Total $TOTAL_STEPS -Title "映射角色 $ROLE_NAME 到用戶 $NEW_USER"

try {
    $roleResponse = Invoke-RestMethod `
        -Uri "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/roles/${ROLE_NAME}" `
        -Method Get -Headers $headers

    $ROLE_ID = $roleResponse.id
    Write-Log "角色 ID: $ROLE_ID" "Green"

    $singleRole = @{
        id   = $ROLE_ID
        name = $ROLE_NAME
    } | ConvertTo-Json -Compress

    $roleMappingPayload = "[$singleRole]"

    Invoke-RestMethod `
        -Uri "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users/${USER_ID}/role-mappings/realm" `
        -Method Post -Headers $headers -Body $roleMappingPayload

    Write-Log "角色映射成功" "Green"
} catch {
    Write-Log "角色映射失敗: $($_.Exception.Message)" "Red"
}

# ========== 步驟 6: 更新 ffm 客戶端 Redirect URIs ==========
Write-StepHeader -Step 6 -Total $TOTAL_STEPS -Title "更新客戶端 $CLIENT_ID 的 Redirect URIs"

try {
    $clientResponse = Invoke-RestMethod `
        -Uri "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=${CLIENT_ID}" `
        -Method Get -Headers $headers

    $CLIENT_INTERNAL_ID = $clientResponse[0].id
    Write-Log "客戶端 $CLIENT_ID 內部 ID: $CLIENT_INTERNAL_ID" "Green"

    $clientUpdatePayload = @{
        redirectUris = @($LOCAL_VM_IP)
    } | ConvertTo-Json

    Invoke-RestMethod `
        -Uri "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${CLIENT_INTERNAL_ID}" `
        -Method Put -Headers $headers -Body $clientUpdatePayload

    Write-Log "客戶端 $CLIENT_ID 更新成功，Redirect URI: $LOCAL_VM_IP" "Green"
} catch {
    Write-Log "更新客戶端 $CLIENT_ID 失敗: $($_.Exception.Message)" "Red"
}

# ========== 步驟 7: 設定 Realm 登入主題 ==========
Write-StepHeader -Step 7 -Total $TOTAL_STEPS -Title "設定 Realm 登入主題為 aiportal-theme"

try {
    $themePayload = @{
        loginTheme = "aiportal-theme"
    } | ConvertTo-Json

    Invoke-RestMethod `
        -Uri "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" `
        -Method Put -Headers $headers -Body $themePayload

    Write-Log "登入主題更新成功" "Green"
} catch {
    Write-Log "更新登入主題失敗: $($_.Exception.Message)" "Red"
}

# ========== 步驟 8: 設定 Realm 語系 ==========
Write-StepHeader -Step 8 -Total $TOTAL_STEPS -Title "設定 Realm 語系為 zhtw"

try {
    $localePayload = @{
        internationalizationEnabled = $true
        supportedLocales = @("zhtw")
        defaultLocale = "zhtw"
    } | ConvertTo-Json

    Invoke-RestMethod `
        -Uri "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" `
        -Method Put -Headers $headers -Body $localePayload

    Write-Log "Realm 語系設定成功" "Green"
} catch {
    Write-Log "設定語系失敗: $($_.Exception.Message)" "Red"
}

# ========== 初始化完成 ==========
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "    Keycloak 初始化完成!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Log "請訪問以下網址進行驗證:"
Write-Log "  Keycloak 管理介面 : https://${VM_IP}:${KEYCLOAK_PORT}/admin"
Write-Log "  Grafana           : http://${VM_IP}:3000"
Write-Log ""
Write-Log "用戶資訊:"
Write-Log "  用戶名 : $NEW_USER"
Write-Log "  密碼   : $NEW_USER_PASSWORD"
Write-Log "  角色   : $ROLE_NAME"
Write-Log "  Realm  : $REALM_NAME"
Write-Log ""
Write-Log "驗證項目:"
Write-Log "  1. Users       - 存在 $NEW_USER 用戶"
Write-Log "  2. Roles       - $NEW_USER 已映射 $ROLE_NAME 角色"
Write-Log "  3. Clients/ffm - Redirect URIs 已更新為 $LOCAL_VM_IP"
Write-Log "  4. Themes      - 登入主題為 aiportal-theme"
Write-Log "  5. Locale      - 預設語系為 zhtw"
Write-Log ""
Write-Log "日誌檔案: $LOG_FILE"