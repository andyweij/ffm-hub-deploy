#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
ENV_FILE="$PROJECT_ROOT/.env"
# 日誌資料夾與檔案設定
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/deploy-step2.log"
SECRET_FILE="$PROJECT_ROOT/config/S3_secret.txt"
# 變數定義
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yaml"
DAEMON_JSON="/etc/docker/daemon.json"
TEMP_JSON="/tmp/daemon.json.tmp"
CERT_DIR="$PROJECT_ROOT/certs/"
CERT_SCRIPT="$SCRIPT_DIR/gen-all-cert.sh"
CURRENT_VM_IP=$(ip -4 addr show $(ip route | grep '^default' | awk '{print $5}') | grep -oP 'inet \K[\d.]+')

# 若 logs 資料夾不存在，則建立
mkdir -p "$LOG_DIR"

exec > >(tee -a "$LOG_FILE") 2>&1
echo "Starting deploy step2 : $(date)"

set -o allexport
source "$ENV_FILE"
set +o allexport

# 檢查 .env 檔案中是否已存在「正確」的 VM_IP
if grep -q "^VM_IP=${CURRENT_VM_IP}$" "$ENV_FILE"; then
    # 如果已存在且正確，就什麼都不做，只印出訊息
    echo "IP in .env is correct: $CURRENT_VM_IP"
else
    # 如果不存在或不正確，就執行更新或新增的邏輯
    echo "IP in .env is incorrect or missing. Updating..."
    echo "CURRENT_VM_IP: $CURRENT_VM_IP"
    echo "VM_IP from ENV: $VM_IP" # $VM_IP 此時可能是舊的 IP 或空值

    # 檢查 .env 中是否「存在」VM_IP 這一行 (不論值為何)
    if grep -q "^VM_IP=" "$ENV_FILE"; then
        # 如果存在，就用 sed 取代
        sed -i "s/^VM_IP=.*/VM_IP=$CURRENT_VM_IP/" "$ENV_FILE"
        echo "已更新 .env 中的 VM_IP 為：$CURRENT_VM_IP"
    else
        # 如果不存在，就用 echo 新增
        # 在新增之前，先檢查檔案末尾是否有換行符
        # 如果沒有，就先追加一個換行符
        if [[ $(tail -c 1 "$ENV_FILE" | wc -l) -eq 0 && $(wc -c < "$ENV_FILE") -ne 0 ]]; then
            echo "" >> "$ENV_FILE" # 添加一個空行，也就是一個換行符
        fi
        
        echo "VM_IP=$CURRENT_VM_IP" >> "$ENV_FILE"
        echo "已新增 VM_IP 至 .env：$CURRENT_VM_IP"
    fi
fi

if [ ! -f "$CERT_SCRIPT" ]; then
    echo "錯誤: 找不到憑證產生腳本 ${CERT_SCRIPT}"
    exit 1
fi

(cd "$SCRIPT_DIR" && bash ./gen-all-cert.sh) || {
    echo "錯誤: 執行 gen-all-cert.sh 失敗"
    exit 1
}

echo "憑證產生腳本執行完畢。"

if [ ! -d "$CERT_DIR" ] || [ ! -f "$ENV_FILE" ] || [ ! -f "$SECRET_FILE" ]; then
    echo "請確認憑證目錄 ($CERT_DIR) 與 .env 檔案 ($ENV_FILE) 是否存在"
    exit 1
fi

# 清理 .env 和 S3_secret.txt 的換行符和 BOM
sed -i -e 's/\r$//' "$ENV_FILE" "$SECRET_FILE"
sed -i '1s/^\xEF\xBB\xBF//' "$ENV_FILE" "$SECRET_FILE"

# 在 while 迴圈之前，加入這段檢查
if [ ! -s "$ENV_FILE" ] || [ -n "$(tail -c1 "$ENV_FILE")" ]; then
    echo "" >> "$ENV_FILE"
fi

# --- 核心邏輯 ---
echo "正在讀取來源檔案 [$SECRET_FILE] 並更新目標檔案 [$ENV_FILE]..."

# 逐行讀取 secret 檔案
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" ]]; then
        continue
    fi

    # 提取 KEY，移除空白和隱藏字元
    KEY=$(echo "$line" | cut -d'=' -f1 | tr -d '[:space:]\r')
    if grep -qE "^[[:space:]]*${KEY}=.*" "$ENV_FILE"; then
        echo "更新 KEY: $KEY"
        sed -i "s#^[[:space:]]*${KEY}=.*#${line}#" "$ENV_FILE"
    else
        echo "新增 KEY: $KEY"
        echo "$line" >> "$ENV_FILE"
    fi
done < "$SECRET_FILE"
echo ".env 檔案更新完成。"

# 從 .env 檔案載入環境變數
set -o allexport
source "$ENV_FILE"
set +o allexport

# 驗證環境變數
if [ -z "$HARBOR_USERNAME" ] || [ -z "$HARBOR_PASSWORD" ] || [ -z "$HARBOR_REGISTRY" ]; then
    echo "$ENV_FILE no params USERNAME or PASSWORD"
    exit 1
fi

echo "設定檔 $ENV_FILE 已更新完成。"

if [ -z "$S3_SECRET_KEY" ] || [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_END_POINT" ] || [ -z "$S3_BUCKET_NAME" ] || [ -z "$S3_PREFIX" ]; then
    echo "$ENV_FILE s3 setting parameter may be empty"
    exit 1
fi

if [ -z "$MODEL_LIST" ]; then
    echo "$ENV_FILE model list setting parameter may be empty"
    exit 1
fi


# 等待 Docker 服務啟動
echo "Waiting for Docker service to start..."
MAX_WAIT=60
WAIT_COUNT=0
until systemctl is-active --quiet docker; do
    echo "Docker service is not ready, waiting..."
    sleep 10
    WAIT_COUNT=$((WAIT_COUNT + 2))
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo "Docker service startup timed out"
        exit 1
    fi
done
echo "Docker service is ready"

# 配置 insecure-registries(正式憑證需移除)
echo "Configuring Docker insecure-registries..."
if [ ! -f "$DAEMON_JSON" ]; then
    echo "{}" | sudo tee "$DAEMON_JSON" > /dev/null
fi

sudo jq \
    --arg reg "$HARBOR_REGISTRY" \
    '."insecure-registries" += [$reg] | ."insecure-registries" |= unique' \
    "$DAEMON_JSON" > "$TEMP_JSON"
sudo cp "$TEMP_JSON" "$DAEMON_JSON"
rm -f "$TEMP_JSON"
sudo systemctl restart docker || {
    echo "Failed to restart Docker"
    exit 1
}

# 再次等待 Docker 服務
echo "Waiting for Docker service to start again..."
WAIT_COUNT=0
until systemctl is-active --quiet docker; do
    echo "Docker service is not ready, waiting..."
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo "Docker service startup timed out"
        exit 1
    fi
done
echo "Docker service is ready"



# 檢查 docker-compose.yaml
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "docker-compose.yaml not found: $COMPOSE_FILE"
    exit 1
fi

# 登錄 Harbor
echo "Logging in to Harbor..."
echo "$HARBOR_PASSWORD" | docker login "$HARBOR_REGISTRY" -u "$HARBOR_USERNAME" --password-stdin || {
    echo "Failed to log in to Harbor"
    exit 1
}

# 啟動 Docker Compose
echo "Starting Docker Compose..."
docker compose --project-directory "$PROJECT_ROOT" -f "$COMPOSE_FILE" up -d --no-recreate || {
    echo "Failed to start Docker Compose"
    exit 1
}

exit 0
