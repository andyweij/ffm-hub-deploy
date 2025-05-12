#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
# 日誌設置
LOG_FILE="$SCRIPT_DIR/deploy-step2.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Starting post-reboot script: $(date)"

# 變數定義
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yaml"
DAEMON_JSON="/etc/docker/daemon.json"
TEMP_JSON="/tmp/daemon.json.tmp"


if [ ! -f "$ENV_FILE" ]; then
    echo "未找到 .env 檔案: $ENV_FILE"
    exit 1
fi

sed -i -e 's/\r$//' $ENV_FILE

# 從 .env 檔案載入環境變數
set -o allexport
source "$ENV_FILE"
set +o allexport

# 驗證環境變數
if [ -z "$HARBOR_USERNAME" ] || [ -z "$HARBOR_PASSWORD" ] || [ -z "$HARBOR_REGISTRY"]; then
    echo "$ENV_FILE no params USERNAME or PASSWORD"
    exit 1
fi


# 安裝 jq（若尚未安裝）
if ! command -v jq &>/dev/null; then
    echo "Installing jq..."
    sudo apt-get update && sudo apt-get install -y jq || {
        echo "Failed to install jq"
        exit 1
    }
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
docker compose -f "$COMPOSE_FILE" up -d || {
    echo "Failed to start Docker Compose"
    exit 1
}


echo "Post-reboot deployment completed"
exit 0
