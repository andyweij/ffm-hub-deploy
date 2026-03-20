# AFS AI Hub - Windows 原生部署指南

本文件說明如何在 Windows 環境下原生部署 PostgreSQL、Keycloak、Prometheus、Grafana 元件（不使用 WSL 與 Docker）。

> **注意**：此部署方案不包含 api-relay 與 aiportal，這兩個元件需另行處理。

---

## 目錄

1. [系統需求](#系統需求)
2. [部署架構](#部署架構)
3. [前置準備](#前置準備)
4. [PostgreSQL 部署](#1-postgresql-部署)
5. [Keycloak 部署](#2-keycloak-部署)
6. [Keycloak 初始化](#3-keycloak-初始化)
7. [Prometheus 部署](#4-prometheus-部署)
8. [Grafana 部署](#5-grafana-部署)
9. [憑證生成](#6-憑證生成)
10. [防火牆設定](#7-防火牆設定)
11. [服務管理](#8-服務管理)
12. [驗證部署](#9-驗證部署)

---

## 系統需求

| 項目 | 最低需求 | 建議配置 |
|------|----------|----------|
| 作業系統 | Windows 10/11 或 Windows Server 2019+ | Windows Server 2022 |
| CPU | Intel i5 / 4 核心 | Intel i7+ / 8 核心 |
| 記憶體 | 8 GB | 16 GB+ |
| 硬碟空間 | 50 GB | 100 GB+ (SSD) |
| 網路 | 靜態 IP | 靜態 IP |

---
## 專案架構
```
afs-ai-hub-installer\ (專案根目錄)
│
├── apps\                   <-- 放入你的 api-relay.jar, aiportal.jar
├── config\                 <-- 放入 afs-ai-hub.json (Keycloak 匯入檔)
├── keycloak_theme\         <-- 放入 aiportal-theme 資料夾
├── packages\               <-- 集中放入所有原始安裝檔
│   ├── openjdk17.zip
│   ├── postgresql-bin.zip
│   ├── keycloak-26.2.0.zip
│   ├── llama-b8196-bin-win-hip-radeon-x64.zip  (及其他 GPU 版本的 zip)
│   └── OpenSSL_Light_3_6_1.msi
├── scripts\                <-- 放入所有的 .ps1 部署腳本
│
└── build.iss               <-- Inno Setup 打包腳本 (稍後建立)
```
## 部署架構

```
┌─────────────────────────────────────────────────────────────┐
│                     Windows Server                          │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │ PostgreSQL  │    │  Keycloak   │    │  Prometheus │      │
│  │   :5432     │◄───│   :8443     │    │    :9090    │      │
│  └─────────────┘    └─────────────┘    └──────┬──────┘      │
│                            │                   │            │
│                            │           ┌──────▼──────┐      │
│                            └──────────►│   Grafana   │      │
│                              SSO       │    :3000    │      │
│                                        └─────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

**元件版本**

| 元件 | 版本 | 埠號 |
|------|------|------|
| PostgreSQL | 16 | 5432 |
| Keycloak | 26.2.0 | 8443, 9000 |
| Prometheus | 2.54.1 | 9090 |
| Grafana | 11.3.0 | 3000 |

---

## 前置準備

### 建立目錄結構

```powershell
# 以管理員身份執行 PowerShell
$BASE_DIR = "C:\afs-ai-hub"

# 建立目錄結構
New-Item -ItemType Directory -Force -Path "$BASE_DIR"
New-Item -ItemType Directory -Force -Path "$BASE_DIR\keycloak"
New-Item -ItemType Directory -Force -Path "$BASE_DIR\prometheus"
New-Item -ItemType Directory -Force -Path "$BASE_DIR\prometheus\data"
New-Item -ItemType Directory -Force -Path "$BASE_DIR\grafana"
New-Item -ItemType Directory -Force -Path "$BASE_DIR\certs\server"
New-Item -ItemType Directory -Force -Path "$BASE_DIR\logs"
```

### 安裝 OpenSSL (用於憑證生成)

1. 下載：https://slproweb.com/products/Win32OpenSSL.html
2. 選擇 `Win64 OpenSSL v3.x.x` (完整版)
3. 安裝後將 `C:\Program Files\OpenSSL-Win64\bin` 加入 PATH

### 下載 NSSM (服務管理工具)

1. 下載：https://nssm.cc/download
2. 解壓縮至 `C:\Tools\nssm`
3. 將路徑加入 PATH 環境變數

---

## 1. PostgreSQL 部署

### 1.1 下載與安裝

1. 官方下載頁面：https://www.postgresql.org/download/windows/
2. 下載 PostgreSQL 16.x Windows 安裝程式 (EDB Installer)
3. 執行安裝程式

**安裝選項**

```
安裝目錄: C:\Program Files\PostgreSQL\16
資料目錄: C:\Program Files\PostgreSQL\16\data
Port: 5432
Superuser (postgres) 密碼: <設定強密碼>
Locale: Chinese (Traditional), Taiwan
```

### 1.2 建立資料庫與使用者

安裝完成後，使用 pgAdmin 或 psql 執行以下 SQL：

```sql
-- 連線至 PostgreSQL (使用 postgres 帳號)

-- 建立 Keycloak 資料庫與使用者
CREATE USER keycloak WITH PASSWORD 'keycloak';
CREATE DATABASE keycloak OWNER keycloak;
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;

-- 建立應用程式資料庫 (供 api-relay 使用)
CREATE USER admin WITH PASSWORD 'admin';
CREATE DATABASE "afs-ai-hub_db" OWNER admin;
GRANT ALL PRIVILEGES ON DATABASE "afs-ai-hub_db" TO admin;
```

或使用 psql 命令列：

```powershell
# 設定環境變數
$env:PGPASSWORD = "your_postgres_password"

# 執行 SQL
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -c "CREATE USER keycloak WITH PASSWORD 'keycloak';"
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -c "CREATE DATABASE keycloak OWNER keycloak;"
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -c "CREATE USER admin WITH PASSWORD 'admin';"
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -c "CREATE DATABASE `"afs-ai-hub_db`" OWNER admin;"
```

### 1.3 設定遠端連線 (可選)

編輯 `C:\Program Files\PostgreSQL\16\data\pg_hba.conf`：

```
# 允許區域網路連線
host    all    all    192.168.0.0/16    scram-sha-256
host    all    all    10.0.0.0/8        scram-sha-256
```

編輯 `C:\Program Files\PostgreSQL\16\data\postgresql.conf`：

```
listen_addresses = '*'
```

重啟服務使設定生效：

```powershell
Restart-Service postgresql-x64-16
```

### 1.4 服務管理

```powershell
# 啟動
Start-Service postgresql-x64-16

# 停止
Stop-Service postgresql-x64-16

# 重啟
Restart-Service postgresql-x64-16

# 查看狀態
Get-Service postgresql-x64-16
```

---

## 2. Keycloak 部署

### 2.1 下載與解壓

1. 官方下載：https://www.keycloak.org/downloads
2. 下載 **Quarkus 發行版**：`keycloak-26.2.0.zip`
3. 解壓至 `C:\afs-ai-hub\keycloak`

```powershell
# 解壓後目錄結構
C:\afs-ai-hub\keycloak\keycloak-26.2.0\
├── bin\
├── conf\
├── lib\
├── providers\
└── themes\
```

### 2.2 配置 Keycloak

編輯 `C:\afs-ai-hub\keycloak\keycloak-26.2.0\conf\keycloak.conf`：

```properties
# 資料庫設定
db=postgres
db-username=keycloak
db-password=keycloak
db-url=jdbc:postgresql://localhost:5432/keycloak

# HTTPS 設定 (使用共用憑證)
https-certificate-file=C:/afs-ai-hub/certs/server/certificate.crt
https-certificate-key-file=C:/afs-ai-hub/certs/server/private.key
https-port=8443

# HTTP 設定 (開發環境可啟用)
# http-enabled=true
# http-port=8080

# 健康檢查
health-enabled=true
metrics-enabled=true

# 主機名稱設定
hostname-strict=false

# 日誌設定
log=console,file
log-file=C:/afs-ai-hub/logs/keycloak.log
```

### 2.3 匯入 Realm 配置

將專案中的 `config/afs-ai-hub.json` 複製到 Keycloak 匯入目錄：

```powershell
# 建立匯入目錄
New-Item -ItemType Directory -Force -Path "C:\afs-ai-hub\keycloak\keycloak-26.2.0\data\import"

# 複製 Realm 配置檔
Copy-Item ".\config\afs-ai-hub.json" "C:\afs-ai-hub\keycloak\keycloak-26.2.0\data\import\"
```

### 2.4 複製自訂主題 (可選)

```powershell
# 複製自訂主題
Copy-Item -Recurse ".\keycloak_theme\*" "C:\afs-ai-hub\keycloak\keycloak-26.2.0\themes\"
```

### 2.5 首次啟動 (含 Realm 匯入)

```powershell
# 設定管理員帳號
$env:KEYCLOAK_ADMIN = "admin"
$env:KEYCLOAK_ADMIN_PASSWORD = "admin"

# 首次啟動 (開發模式 + 匯入 Realm)
cd C:\afs-ai-hub\keycloak\keycloak-26.2.0
.\bin\kc.bat start-dev --import-realm
```

### 2.6 註冊為 Windows Service

```powershell
# 使用 NSSM 註冊服務
nssm install Keycloak "C:\afs-ai-hub\keycloak\keycloak-26.2.0\bin\kc.bat" "start-dev"
nssm set Keycloak AppDirectory "C:\afs-ai-hub\keycloak\keycloak-26.2.0"
nssm set Keycloak AppEnvironmentExtra "KEYCLOAK_ADMIN=admin" "KEYCLOAK_ADMIN_PASSWORD=admin"
nssm set Keycloak DisplayName "Keycloak Identity Server"
nssm set Keycloak Description "Keycloak 26.2.0 - Identity and Access Management"
nssm set Keycloak Start SERVICE_AUTO_START
nssm set Keycloak AppStdout "C:\afs-ai-hub\logs\keycloak-stdout.log"
nssm set Keycloak AppStderr "C:\afs-ai-hub\logs\keycloak-stderr.log"

# 啟動服務
nssm start Keycloak
```

### 2.7 驗證 Keycloak

- 管理介面：https://localhost:8443/admin
- 帳號：admin / admin
- 健康檢查：https://localhost:9000/health

---

## 3. Keycloak 初始化

Keycloak 啟動後需要執行初始化腳本，完成以下配置：

- 創建應用程式用戶 (afs-admin)
- 設置用戶密碼
- 映射 admin 角色到用戶
- 更新 ffm 客戶端的 Redirect URIs
- 配置 grafana-oauth 客戶端
- 設定登入主題 (aiportal-theme)
- 設定 Realm 語系 (zhtw)

### 3.1 使用 PowerShell 初始化腳本

專案提供了 `init-keycloak.ps1` 腳本自動完成初始化：

```powershell
# 執行初始化腳本
.\scripts\init-keycloak.ps1 -VM_IP "192.168.1.100"

# 或指定所有參數
.\scripts\init-keycloak.ps1 `
    -VM_IP "192.168.1.100" `
    -NEW_USER "afs-admin" `
    -NEW_USER_PASSWORD "afs-admin" `
    -REALM_NAME "ffm-realm" `
    -ADMIN_USERNAME "admin" `
    -ADMIN_PASSWORD "admin"
```

### 3.2 初始化腳本功能說明

| 步驟 | 說明 |
|------|------|
| 1 | 等待 Keycloak 健康檢查通過 |
| 2 | 獲取管理員 access token |
| 3 | 創建新用戶 (afs-admin) |
| 4 | 設置用戶密碼 |
| 5 | 獲取 admin 角色 ID |
| 6 | 映射 admin 角色到用戶 |
| 7 | 更新 ffm 客戶端 Redirect URIs |
| 8 | 更新 grafana-oauth 客戶端配置 |
| 9 | 設定登入主題為 aiportal-theme |
| 10 | 設定 Realm 語系為 zhtw |

### 3.3 手動初始化 (可選)

如需手動執行初始化，可使用以下 API 呼叫：

#### 3.3.1 獲取 Access Token

```powershell
# 忽略 SSL 憑證驗證
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$tokenBody = @{
    client_id = "admin-cli"
    username = "admin"
    password = "admin"
    grant_type = "password"
}

$tokenResponse = Invoke-RestMethod -Uri "https://localhost:8443/realms/master/protocol/openid-connect/token" `
    -Method Post -Body $tokenBody -ContentType "application/x-www-form-urlencoded"

$ACCESS_TOKEN = $tokenResponse.access_token

$headers = @{
    "Authorization" = "Bearer $ACCESS_TOKEN"
    "Content-Type" = "application/json"
}
```

#### 3.3.2 創建用戶

```powershell
$VM_IP = "192.168.1.100"
$REALM_NAME = "ffm-realm"
$NEW_USER = "afs-admin"
$NEW_USER_PASSWORD = "afs-admin"

# 創建用戶
$userPayload = @{
    username = $NEW_USER
    enabled = $true
    requiredActions = @("terms_and_conditions")
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://localhost:8443/admin/realms/${REALM_NAME}/users" `
    -Method Post -Headers $headers -Body $userPayload
```

#### 3.3.3 設置密碼

```powershell
# 獲取用戶 ID
$userResponse = Invoke-RestMethod -Uri "https://localhost:8443/admin/realms/${REALM_NAME}/users?username=${NEW_USER}" `
    -Method Get -Headers $headers
$USER_ID = $userResponse[0].id

# 設置密碼
$passwordPayload = @{
    type = "password"
    value = $NEW_USER_PASSWORD
    temporary = $false
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://localhost:8443/admin/realms/${REALM_NAME}/users/${USER_ID}/reset-password" `
    -Method Put -Headers $headers -Body $passwordPayload
```

#### 3.3.4 映射角色

```powershell
# 獲取角色 ID
$roleResponse = Invoke-RestMethod -Uri "https://localhost:8443/admin/realms/${REALM_NAME}/roles/admin" `
    -Method Get -Headers $headers
$ROLE_ID = $roleResponse.id

# 映射角色
$roleMappingPayload = @(
    @{
        id = $ROLE_ID
        name = "admin"
    }
) | ConvertTo-Json

Invoke-RestMethod -Uri "https://localhost:8443/admin/realms/${REALM_NAME}/users/${USER_ID}/role-mappings/realm" `
    -Method Post -Headers $headers -Body $roleMappingPayload
```

#### 3.3.5 更新客戶端 Redirect URIs

```powershell
# 更新 ffm 客戶端
$clientResponse = Invoke-RestMethod -Uri "https://localhost:8443/admin/realms/${REALM_NAME}/clients?clientId=ffm" `
    -Method Get -Headers $headers
$CLIENT_ID = $clientResponse[0].id

$clientPayload = @{
    redirectUris = @("https://${VM_IP}/*")
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://localhost:8443/admin/realms/${REALM_NAME}/clients/${CLIENT_ID}" `
    -Method Put -Headers $headers -Body $clientPayload

# 更新 grafana-oauth 客戶端
$grafanaClientResponse = Invoke-RestMethod -Uri "https://localhost:8443/admin/realms/${REALM_NAME}/clients?clientId=grafana-oauth" `
    -Method Get -Headers $headers
$GRAFANA_CLIENT_ID = $grafanaClientResponse[0].id

$grafanaPayload = @{
    rootUrl = "http://${VM_IP}:3000/"
    adminUrl = "http://${VM_IP}:3000/"
    redirectUris = @("http://${VM_IP}:3000/*")
    webOrigins = @("http://${VM_IP}:3000/")
    attributes = @{
        "post.logout.redirect.uris" = "http://${VM_IP}:3000/*"
    }
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri "https://localhost:8443/admin/realms/${REALM_NAME}/clients/${GRAFANA_CLIENT_ID}" `
    -Method Put -Headers $headers -Body $grafanaPayload
```

#### 3.3.6 設定 Realm 主題與語系

```powershell
# 獲取 Realm 配置
$realmConfig = Invoke-RestMethod -Uri "https://localhost:8443/admin/realms/${REALM_NAME}" `
    -Method Get -Headers $headers

# 更新主題和語系
$realmConfig.loginTheme = "aiportal-theme"
$realmConfig.internationalizationEnabled = $true
$realmConfig.supportedLocales = @("zhtw")
$realmConfig.defaultLocale = "zhtw"

$realmConfigJson = $realmConfig | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri "https://localhost:8443/admin/realms/${REALM_NAME}" `
    -Method Put -Headers $headers -Body $realmConfigJson
```

### 3.4 驗證初始化結果

1. 登入 Keycloak 管理介面：https://localhost:8443/admin
2. 進入 Realm `ffm-realm`
3. 確認以下項目：
   - **Users**：存在 `afs-admin` 用戶
   - **Users → afs-admin → Role Mappings**：已映射 `admin` 角色
   - **Clients → ffm**：Valid Redirect URIs 已更新
   - **Clients → grafana-oauth**：Root URL 和 Redirect URIs 已更新
   - **Realm Settings → Themes**：Login theme 為 `aiportal-theme`
   - **Realm Settings → Localization**：Default locale 為 `zhtw`

---

## 4. Prometheus 部署

### 4.1 下載與解壓

1. 官方下載：https://prometheus.io/download/
2. 下載 `prometheus-2.54.1.windows-amd64.zip`
3. 解壓至 `C:\afs-ai-hub\prometheus`

### 4.2 配置 Prometheus

建立配置檔 `C:\afs-ai-hub\prometheus\prometheus.yml`：

```yaml
# Prometheus 配置檔

global:
  scrape_interval: 5s
  evaluation_interval: 30s

scrape_configs:
  # vLLM 模型服務監控
  - job_name: vllm
    static_configs:
      - targets:
          - 'localhost:8000'
          - 'localhost:8001'
          - 'localhost:8002'
          - 'localhost:8003'
          - 'localhost:8004'

  # Prometheus 自身監控
  - job_name: prometheus
    static_configs:
      - targets:
          - 'localhost:9090'

  # Keycloak 監控 (可選)
  # - job_name: keycloak
  #   metrics_path: /metrics
  #   static_configs:
  #     - targets:
  #         - 'localhost:9000'
```

### 4.3 測試啟動

```powershell
cd C:\afs-ai-hub\prometheus
.\prometheus.exe --config.file=prometheus.yml --storage.tsdb.path=data --web.listen-address=:9090
```

### 4.4 註冊為 Windows Service

```powershell
# 使用 NSSM 註冊服務
nssm install Prometheus "C:\afs-ai-hub\prometheus\prometheus.exe"
nssm set Prometheus AppParameters "--config.file=C:\afs-ai-hub\prometheus\prometheus.yml --storage.tsdb.path=C:\afs-ai-hub\prometheus\data --web.listen-address=:9090"
nssm set Prometheus AppDirectory "C:\afs-ai-hub\prometheus"
nssm set Prometheus DisplayName "Prometheus Monitoring"
nssm set Prometheus Description "Prometheus v2.54.1 - Monitoring System"
nssm set Prometheus Start SERVICE_AUTO_START
nssm set Prometheus AppStdout "C:\afs-ai-hub\logs\prometheus-stdout.log"
nssm set Prometheus AppStderr "C:\afs-ai-hub\logs\prometheus-stderr.log"

# 啟動服務
nssm start Prometheus
```

### 4.5 驗證 Prometheus

- Web UI：http://localhost:9090
- 健康檢查：http://localhost:9090/-/healthy
- Targets 狀態：http://localhost:9090/targets

---

## 5. Grafana 部署

### 5.1 下載與安裝

1. 官方下載：https://grafana.com/grafana/download?platform=windows
2. 下載 Windows Installer (MSI)：`grafana-enterprise-11.3.0.windows-amd64.msi`
3. 執行安裝程式

**預設安裝路徑**：`C:\Program Files\GrafanaLabs\grafana`

### 5.2 配置 Grafana

建立自訂配置檔 `C:\Program Files\GrafanaLabs\grafana\conf\custom.ini`：

```ini
#################################### Server ####################################
[server]
http_port = 3000
# 請將 <YOUR_IP> 替換為實際 IP
root_url = http://<YOUR_IP>:3000

#################################### Security ####################################
[security]
admin_user = admin
admin_password = admin

#################################### Paths ####################################
[paths]
provisioning = conf/provisioning

#################################### Auth - Keycloak SSO ####################################
[auth.generic_oauth]
enabled = true
name = Keycloak SSO
allow_sign_up = true
client_id = grafana-oauth
client_secret = La5u4P1CleaXDx8BHypFRXPXknnSSnH3
scopes = openid profile email

# 請將 <YOUR_IP> 替換為實際 IP
auth_url = https://<YOUR_IP>:8443/realms/ffm-realm/protocol/openid-connect/auth
token_url = https://<YOUR_IP>:8443/realms/ffm-realm/protocol/openid-connect/token
api_url = https://<YOUR_IP>:8443/realms/ffm-realm/protocol/openid-connect/userinfo

email_attribute_path = email
login_attribute_path = preferred_username
name_attribute_path = name
role_attribute_path = contains(realm_access.roles[*], 'admin') && 'Admin' || 'Viewer'
allow_assign_grafana_admin = true
skip_org_role_sync = false
tls_skip_verify_insecure = true
```

### 5.3 配置資料來源 (Provisioning)

建立目錄和配置檔：

```powershell
New-Item -ItemType Directory -Force -Path "C:\Program Files\GrafanaLabs\grafana\conf\provisioning\datasources"
```

建立 `C:\Program Files\GrafanaLabs\grafana\conf\provisioning\datasources\prometheus.yaml`：

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
```

### 5.4 配置儀表板 (Provisioning)

建立目錄：

```powershell
New-Item -ItemType Directory -Force -Path "C:\Program Files\GrafanaLabs\grafana\conf\provisioning\dashboards"
New-Item -ItemType Directory -Force -Path "C:\Program Files\GrafanaLabs\grafana\dashboards"
```

建立 `C:\Program Files\GrafanaLabs\grafana\conf\provisioning\dashboards\dashboards.yaml`：

```yaml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: C:/Program Files/GrafanaLabs/grafana/dashboards
```

複製專案中的儀表板：

```powershell
Copy-Item ".\config\grafana\dashboards\grafana.json" "C:\Program Files\GrafanaLabs\grafana\dashboards\"
```

### 5.5 啟動服務

Grafana MSI 安裝會自動註冊 Windows Service：

```powershell
# 啟動
Start-Service Grafana

# 停止
Stop-Service Grafana

# 重啟
Restart-Service Grafana

# 查看狀態
Get-Service Grafana
```

### 5.6 驗證 Grafana

- Web UI：http://localhost:3000
- 預設帳號：admin / admin
- 確認 Prometheus 資料來源已連線：Configuration → Data Sources

---

## 6. 憑證生成

使用專案提供的 Windows 憑證生成腳本，生成供所有元件共用的 SSL 憑證。

### 6.1 使用 PowerShell 腳本

```powershell
# 執行憑證生成腳本
.\scripts\gen-all-cert.ps1 -VM_IP "192.168.1.100"
```

### 6.2 使用批次檔

```batch
scripts\gen-all-cert.bat 192.168.1.100
```

### 6.3 生成的憑證

```
certs\server\
├── private.key         # 私鑰
├── certificate.crt     # 公開憑證
├── keystore.p12        # PKCS12 Keystore (密碼: changeit)
└── request.csr         # CSR (可刪除)
```

### 6.4 憑證 SAN (Subject Alternative Name)

```
IP  : <YOUR_IP>, 127.0.0.1
DNS : aiportal, api-relay, keycloak, localhost
```

### 6.5 將憑證加入 Windows 信任根憑證

```powershell
# 以管理員身份執行
Import-Certificate -FilePath "C:\afs-ai-hub\certs\server\certificate.crt" -CertStoreLocation Cert:\LocalMachine\Root
```

或使用 certutil：

```batch
certutil -addstore -f "ROOT" "C:\afs-ai-hub\certs\server\certificate.crt"
```

---

## 7. 防火牆設定

### 7.1. 註冊 API-Relay 服務
- 此服務已針對 Windows 環境優化，改用 llama-cpp 引擎策略以對應 AMD NPU/GPU 設備。

```PowerShell
# 設定變數
$NSSM = "C:\tools\nssm.exe"
$JAVA = "C:\Program Files\Java\jdk-17\bin\java.exe"
$APP_ROOT = "C:\afs-ai-hub"

# 1. 建立服務
& $NSSM install "afs-api-relay" "$JAVA" "-jar $APP_ROOT\api-relay.jar"

# 2. 設定工作目錄
& $NSSM set "afs-api-relay" AppDirectory "$APP_ROOT"

# 3. 注入環境變數 (參考 start-api-relay.ps1 配置)
$envParams = @(
"ENGINE_TYPE=llama-cpp",
"SERVER_PORT=8080",
"SERVER_SSL_ENABLED=false",
"KEYCLOAK_SERVER_URL=http://localhost:8443",
"LOCAL_DIR=afs-ai-hub",
"HOST_IP=localhost",
"API_RELAY_PORT=8080"
)
& $NSSM set "afs-api-relay" AppEnvironmentExtra $envParams

# 4. 設定重啟機制與日誌
& $NSSM set "afs-api-relay" AppStdout "$APP_ROOT\logs\api-relay-stdout.log"
& $NSSM set "afs-api-relay" AppStderr "$APP_ROOT\logs\api-relay-stderr.log"

# 5. 啟動服務
Start-Service "afs-api-relay"
```
### 7.2. 註冊 AIPortal 服務
- aiportal 服務通常涉及 SSL 憑證，啟動前請確保 keystore.p12 已就緒。

```PowerShell
# 1. 建立服務
& $NSSM install "afs-aiportal" "$JAVA" "-DSPRING_PROFILES_ACTIVE=stage -jar $APP_ROOT\aiportal.jar"

# 2. 設定工作目錄
& $NSSM set "afs-aiportal" AppDirectory "$APP_ROOT"

# 3. 注入環境變數 (根據 docker-compose 設定)
$portalEnv = @(
"SERVER_PORT=8443",
"SERVER_SSL_ENABLED=true",
"SERVER_SSL_KEYSTORE=$APP_ROOT\certs\keystore.p12",
"SERVER_SSL_KEYSTORE_PASSWORD=changeit",
"APIMODULE_URL=http://localhost:8080",
"FRONTEND_KEYCLOAK_URL=https://localhost:8443"
)
& $NSSM set "afs-aiportal" AppEnvironmentExtra $portalEnv

# 4. 設定服務依賴關係 (確保資料庫與 API-Relay 先啟動)
& $NSSM set "afs-aiportal" DependOnService "postgresql-x64-16" "afs-api-relay"

# 5. 啟動服務
Start-Service "afs-aiportal"
```
```powershell
# 以管理員身份執行 PowerShell

# PostgreSQL
New-NetFirewallRule -DisplayName "PostgreSQL" -Direction Inbound -LocalPort 5432 -Protocol TCP -Action Allow

# Keycloak HTTPS
New-NetFirewallRule -DisplayName "Keycloak HTTPS" -Direction Inbound -LocalPort 8443 -Protocol TCP -Action Allow

# Keycloak Management
New-NetFirewallRule -DisplayName "Keycloak Management" -Direction Inbound -LocalPort 9000 -Protocol TCP -Action Allow

# Prometheus
New-NetFirewallRule -DisplayName "Prometheus" -Direction Inbound -LocalPort 9090 -Protocol TCP -Action Allow

# Grafana
New-NetFirewallRule -DisplayName "Grafana" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow

# vLLM 模型服務 (如需要)
New-NetFirewallRule -DisplayName "vLLM Services" -Direction Inbound -LocalPort 8000-8004 -Protocol TCP -Action Allow
```

---

## 8. 服務管理

### 8.1 服務列表

| 服務名稱 | 類型 | 管理方式 |
|----------|------|----------|
| postgresql-x64-16 | Windows Service (自動) | services.msc / PowerShell |
| Keycloak | NSSM Service | nssm / services.msc |
| Prometheus | NSSM Service | nssm / services.msc |
| Grafana | Windows Service (自動) | services.msc / PowerShell |

### 8.2 啟動順序

```powershell
# 1. PostgreSQL (通常已自動啟動)
Start-Service postgresql-x64-16

# 2. 等待 PostgreSQL 就緒後啟動 Keycloak
Start-Sleep -Seconds 5
nssm start Keycloak

# 3. 等待 Keycloak 就緒後執行初始化 (首次部署)
Start-Sleep -Seconds 30
.\scripts\init-keycloak.ps1 -VM_IP "<YOUR_IP>"

# 4. Prometheus
nssm start Prometheus

# 5. Grafana
Start-Service Grafana
```

### 8.3 停止所有服務

```powershell
Stop-Service Grafana
nssm stop Prometheus
nssm stop Keycloak
Stop-Service postgresql-x64-16
```

### 8.4 查看所有服務狀態

```powershell
Get-Service postgresql-x64-16, Grafana | Format-Table Name, Status
nssm status Keycloak
nssm status Prometheus
```

### 8.5 NSSM 服務管理命令

```powershell
# 編輯服務設定 (GUI)
nssm edit <ServiceName>

# 移除服務
nssm remove <ServiceName> confirm

# 查看服務狀態
nssm status <ServiceName>

# 重啟服務
nssm restart <ServiceName>
```

---

## 9. 驗證部署

### 9.1 檢查服務狀態

```powershell
# PowerShell 腳本：檢查所有服務
$services = @(
    @{Name="PostgreSQL"; Port=5432; URL=""},
    @{Name="Keycloak"; Port=8443; URL="https://localhost:8443/health"},
    @{Name="Prometheus"; Port=9090; URL="http://localhost:9090/-/healthy"},
    @{Name="Grafana"; Port=3000; URL="http://localhost:3000/api/health"}
)

foreach ($svc in $services) {
    $tcpTest = Test-NetConnection -ComputerName localhost -Port $svc.Port -WarningAction SilentlyContinue
    if ($tcpTest.TcpTestSucceeded) {
        Write-Host "$($svc.Name): OK (Port $($svc.Port))" -ForegroundColor Green
    } else {
        Write-Host "$($svc.Name): FAILED (Port $($svc.Port))" -ForegroundColor Red
    }
}
```

### 9.2 存取介面

| 元件 | URL | 預設帳號 |
|------|-----|----------|
| Keycloak Admin | https://localhost:8443/admin | admin / admin |
| Prometheus | http://localhost:9090 | - |
| Grafana | http://localhost:3000 | admin / admin |

### 9.3 測試 Keycloak 與 Grafana SSO

1. 開啟 Grafana：http://localhost:3000
2. 點選「Sign in with Keycloak SSO」
3. 使用 Keycloak 帳號登入
4. 確認角色對應正確

---

## 附錄

### A. 環境變數配置範本

建立 `C:\afs-ai-hub\.env` 檔案：

```properties
# 主機 IP
VM_IP=192.168.1.100

# Keycloak
REALM_NAME=ffm-realm
NEW_USER=afs-admin
NEW_USER_PASSWORD=afs-admin

# 資料庫
POSTGRES_USER=keycloak
POSTGRES_PASSWORD=keycloak

# Grafana OAuth
GRAFANA_OAUTH_CLIENT_SECRET=La5u4P1CleaXDx8BHypFRXPXknnSSnH3

# 憑證
CERT_PASSWORD=changeit
```

### B. 日誌檔案位置

| 元件 | 日誌位置 |
|------|----------|
| PostgreSQL | `C:\Program Files\PostgreSQL\16\data\log\` |
| Keycloak | `C:\afs-ai-hub\logs\keycloak*.log` |
| Prometheus | `C:\afs-ai-hub\logs\prometheus*.log` |
| Grafana | `C:\Program Files\GrafanaLabs\grafana\data\log\` |

### C. 常見問題

**Q: Keycloak 無法連線到 PostgreSQL**

檢查：
1. PostgreSQL 服務是否啟動
2. 防火牆是否開放 5432 埠
3. `keycloak.conf` 中的資料庫連線字串是否正確

**Q: Grafana SSO 登入失敗**

檢查：
1. Keycloak 是否正常運作
2. `custom.ini` 中的 URL 是否使用正確的 IP
3. OAuth Client Secret 是否正確
4. 憑證是否已加入信任根憑證

**Q: Prometheus 無法抓取 metrics**

檢查：
1. 目標服務是否啟動
2. 防火牆是否開放對應埠號
3. `prometheus.yml` 中的 targets 是否正確

---

## 版本紀錄

| 版本 | 日期 | 說明 |
|------|------|------|
| 1.0.0 | 2024-01 | 初始版本 |