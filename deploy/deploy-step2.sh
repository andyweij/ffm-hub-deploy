#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/config/.env"
# 日誌資料夾與檔案設定
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/deploy-step2.log"

# 若 logs 資料夾不存在，則建立
mkdir -p "$LOG_DIR"

exec > >(tee -a "$LOG_FILE") 2>&1
echo "Starting deploy step2 : $(date)"

# 變數定義
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yaml"
DAEMON_JSON="/etc/docker/daemon.json"
TEMP_JSON="/tmp/daemon.json.tmp"
CERT_DIR="$SCRIPT_DIR/certs/"
CURRENT_VM_IP=$(curl -s ifconfig.me)

if [ ! -d "$CERT_DIR" ] || [ ! -f "$ENV_FILE" ]; then
    echo "請確認憑證目錄 ($CERT_DIR) 與 .env 檔案 ($ENV_FILE) 是否存在"
    exit 1
fi

sed -i -e 's/\r$//' $ENV_FILE

# 從 .env 檔案載入環境變數
set -o allexport
source "$ENV_FILE"
set +o allexport

# 驗證環境變數
if [ -z "$HARBOR_USERNAME" ] || [ -z "$HARBOR_PASSWORD" ] || [ -z "$HARBOR_REGISTRY" ]; then
    echo "$ENV_FILE no params USERNAME or PASSWORD"
    exit 1
fi

if [ -z "$S3_SECRET_KEY" ] || [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_END_POINT" ] || [ -z "$S3_BUCKET_NAME" ] || [ -z "$S3_PREFIX" ]; then
    echo "$ENV_FILE s3 setting parameter may be empty"
    exit 1
fi

if [ -z "$MODEL_LIST" ]; then
    echo "$ENV_FILE model list setting parameter may be empty"
    exit 1
fi

# 檢查 VM_IP 是否為空
if [ -z "$VM_IP" ]; then
    echo "VM_IP is not set in the .env file."
    exit 1
fi

# 比對 IP
if [ "$CURRENT_VM_IP" = "$VM_IP" ]; then
    echo "IP 相同：$CURRENT_VM_IP"
else
    echo "IP 不相同，準備更新 .env 中的 VM_IP"
    echo "CURRENT_VM_IP: $CURRENT_VM_IP"
    echo "VM_IP from ENV: $VM_IP"

    if grep -q "^VM_IP=" "$ENV_FILE"; then
        sed -i "s/^VM_IP=.*/VM_IP=$CURRENT_VM_IP/" "$ENV_FILE"
        echo "已更新 .env 中的 VM_IP 為：$CURRENT_VM_IP"
    else
        echo "VM_IP=$CURRENT_VM_IP" >> "$ENV_FILE"
        echo "已新增 VM_IP 至 .env：$CURRENT_VM_IP"
    fi

    # 重新載入 .env（以使用新 IP）
    set -o allexport
    source "$ENV_FILE"
    set +o allexport
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
docker compose -f "$COMPOSE_FILE" up -d --no-recreate|| {
    echo "Failed to start Docker Compose"
    exit 1
}

# 執行 deploy-step3.sh
echo "Executing init-keycloak.sh..."
INIT_KEYCLOAK="$SCRIPT_DIR/init-keycloak.sh"
if [ ! -f "$INIT_KEYCLOAK" ]; then
    echo "Can't find init-keycloak.sh file: $INIT_KEYCLOAK"
    exit 1
fi
bash "$INIT_KEYCLOAK" || {
    echo "Failed to execute init-keycloak.sh"
    exit 1
}

echo "FFM-HUB Service Deployment completed"
exit 0
