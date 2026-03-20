# ========== gen-all-cert.ps1 ==========
# Windows 版本的共用憑證生成腳本
# 與 Linux 版 gen-all-cert.sh 功能對應
# 生成的憑證可供 aiportal, api-relay, keycloak 共用

param(
    [string]$VM_IP = $(Read-Host "請輸入主機 IP 位址")
)

# ========== 基本配置 ==========
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$CERT_DIR = Join-Path $PROJECT_ROOT "certs"
$SERVER_CERT_DIR = Join-Path $CERT_DIR "server"
$PASSWORD = "changeit"
$DAYS = 3650

# ========== 驗證 IP ==========
if ([string]::IsNullOrWhiteSpace($VM_IP)) {
    Write-Host "錯誤：IP 位址不能為空" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========== AFS AI Hub 憑證生成工具 (Windows) ==========" -ForegroundColor Cyan
Write-Host "主機 IP: $VM_IP"
Write-Host "憑證有效期: $DAYS 天"
Write-Host ""

# ========== 檢查 OpenSSL ==========
try {
    $opensslVersion = & openssl version 2>&1
    Write-Host "OpenSSL 版本: $opensslVersion" -ForegroundColor Gray
} catch {
    Write-Host "錯誤：找不到 OpenSSL，請先安裝 OpenSSL for Windows" -ForegroundColor Red
    Write-Host "下載連結: https://slproweb.com/products/Win32OpenSSL.html" -ForegroundColor Yellow
    exit 1
}

# ========== 清理並建立目錄 ==========
Write-Host ""
Write-Host "清理並建立憑證目錄..."
if (Test-Path $CERT_DIR) {
    Remove-Item -Recurse -Force $CERT_DIR
}
New-Item -ItemType Directory -Force -Path $SERVER_CERT_DIR | Out-Null

# ========== 建立 OpenSSL 擴展配置檔 ==========
$EXT_TEMPLATE = Join-Path $CERT_DIR "v3_ext.cnf"

$extContent = @"
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = TW
ST = Taiwan
L = Taipei
O = AFS
OU = Server
CN = $VM_IP

[v3_req]
basicConstraints = critical,CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
subjectAltName = @alt_names

[alt_names]
IP.1 = $VM_IP
IP.2 = 127.0.0.1
DNS.1 = afs-ai-hub.local
DNS.2 = localhost
"@

Set-Content -Path $EXT_TEMPLATE -Value $extContent -Encoding UTF8
Write-Host "已建立 OpenSSL 配置檔: $EXT_TEMPLATE"

Write-Host ""
Write-Host "正在生成共用伺服器憑證..." -ForegroundColor Cyan

# ========== Step 1: 生成私鑰 ==========
Write-Host "[1/5] 生成私鑰 (RSA 2048-bit)..."
$privateKeyPath = Join-Path $SERVER_CERT_DIR "private.key"
& openssl genpkey -algorithm RSA -out $privateKeyPath -pkeyopt rsa_keygen_bits:2048 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "錯誤：生成私鑰失敗" -ForegroundColor Red
    exit 1
}
Write-Host "  -> $privateKeyPath" -ForegroundColor Green

# ========== Step 2: 生成 CSR ==========
Write-Host "[2/5] 生成憑證簽署請求 (CSR)..."
$csrPath = Join-Path $SERVER_CERT_DIR "request.csr"
& openssl req -new -key $privateKeyPath -out $csrPath -config $EXT_TEMPLATE 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "錯誤：生成 CSR 失敗" -ForegroundColor Red
    exit 1
}
Write-Host "  -> $csrPath" -ForegroundColor Green

# ========== Step 3: 自簽憑證 ==========
Write-Host "[3/5] 簽署憑證 (自簽, SHA-256)..."
$certPath = Join-Path $SERVER_CERT_DIR "certificate.crt"
& openssl x509 -req -in $csrPath -signkey $privateKeyPath -out $certPath -days $DAYS -sha256 -extensions v3_req -extfile $EXT_TEMPLATE 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "錯誤：簽署憑證失敗" -ForegroundColor Red
    exit 1
}
Write-Host "  -> $certPath" -ForegroundColor Green

# ========== Step 4: 驗證 SAN ==========
Write-Host "[4/5] 驗證 Subject Alternative Name..."
$sanInfo = & openssl x509 -in $certPath -noout -text 2>&1 | Select-String -Pattern "Subject Alternative Name" -Context 0,1
if ($sanInfo) {
    Write-Host $sanInfo -ForegroundColor Gray
} else {
    Write-Host "  警告：無法讀取 SAN 資訊" -ForegroundColor Yellow
}

# ========== Step 5: 生成 PKCS12 Keystore ==========
Write-Host "[5/5] 生成 PKCS12 Keystore..."
$keystorePath = Join-Path $SERVER_CERT_DIR "keystore.p12"
& openssl pkcs12 -export -in $certPath -inkey $privateKeyPath -out $keystorePath -name "server" -passout pass:$PASSWORD 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "錯誤：生成 Keystore 失敗" -ForegroundColor Red
    exit 1
}
Write-Host "  -> $keystorePath" -ForegroundColor Green
# ========== 完成摘要 ==========
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "       憑證生成完成                    " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "憑證目錄: $SERVER_CERT_DIR"
Write-Host ""
Write-Host "生成的檔案:" -ForegroundColor Cyan
Write-Host "  private.key      - 私鑰 (RSA 2048-bit)"
Write-Host "  certificate.crt  - 公開憑證 (X.509)"
Write-Host "  keystore.p12     - PKCS12 Keystore (密碼: $PASSWORD)"
Write-Host "  request.csr      - 憑證簽署請求 (可刪除)"
Write-Host ""
Write-Host "SAN (Subject Alternative Name):" -ForegroundColor Cyan
Write-Host "  IP  : $VM_IP, 127.0.0.1"
Write-Host "  DNS : aiportal, api-relay, keycloak, localhost"
Write-Host ""
Write-Host "----------------------------------------"
Write-Host "各元件配置說明:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Keycloak (keycloak.conf):"
Write-Host "  https-certificate-file=$SERVER_CERT_DIR\certificate.crt"
Write-Host "  https-certificate-key-file=$SERVER_CERT_DIR\private.key"
Write-Host ""
Write-Host "Java 應用 (aiportal, api-relay):"
Write-Host "  使用 keystore.p12, 密碼: $PASSWORD"
Write-Host ""
Write-Host "將憑證加入 Windows 信任根憑證 (需管理員權限):"
Write-Host "  Import-Certificate -FilePath `"$certPath`" -CertStoreLocation Cert:\LocalMachine\Root"
Write-Host ""