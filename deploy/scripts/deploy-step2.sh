#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
ENV_FILE="$PROJECT_ROOT/.env"
# 日誌資料夾與檔案設定
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/deploy-step2.log"
# 變數定義
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yaml"
DAEMON_JSON="/etc/docker/daemon.json"
TEMP_JSON="/tmp/daemon.json.tmp"
CERT_DIR="$PROJECT_ROOT/certs/"
CERT_SCRIPT="$SCRIPT_DIR/gen-all-cert.sh"
#CURRENT_VM_IP=$(curl -s ifconfig.me)

# 若 logs 資料夾不存在，則建立
mkdir -p "$LOG_DIR"

exec > >(tee -a "$LOG_FILE") 2>&1
echo "Starting deploy step2 : $(date)"

if [ -f "$ENV_FILE" ]; then
    set -o allexport
    source "$ENV_FILE"
    set +o allexport
fi

# 根據 .env 中的設定選擇 IP 取得方式
MAX_RETRIES=10
RETRY_COUNT=0

if [ "$IP_ACQUISITION_METHOD" == "local" ]; then
    echo "使用本地 IP 取得方式，等待網路穩定..."
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        # 取得預設路由網卡，並排除 docker 相關字眼
        DEFAULT_IFACE=$(ip route | grep '^default' | grep -v 'docker' | awk '{print $5}' | head -n 1)
        
        if [ -n "$DEFAULT_IFACE" ]; then
            # 取得該網卡的 IPv4，並確保只取第一行
            CURRENT_VM_IP=$(ip -4 addr show "$DEFAULT_IFACE" | grep -oP 'inet \K[\d.]+' | head -n 1)
            
            # 確保抓到的不是回環位址 (127.x.x.x) 或 Docker 預設網段 (172.x.x.x)
            if [[ -n "$CURRENT_VM_IP" && ! "$CURRENT_VM_IP" =~ ^172\. && "$CURRENT_VM_IP" != "127.0.0.1" ]]; then
                echo "成功取得有效的本地 IP: $CURRENT_VM_IP"
                break
            fi
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "尚未取得有效 IP，等待中... ($RETRY_COUNT/$MAX_RETRIES)"
        sleep 3
    done

    if [ -z "$CURRENT_VM_IP" ]; then
        echo "錯誤: 超過重試次數，無法取得有效的本地 IP。"
        exit 1
    fi
else
    echo "使用公開 IP 取得方式 (預設)。"
    CURRENT_VM_IP=$(curl -s ifconfig.me)
fi
# --- IP 取得邏輯結束 ---

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

if [ ! -d "$CERT_DIR" ] || [ ! -f "$ENV_FILE" ]; then
    echo "請確認憑證目錄 ($CERT_DIR) 與 .env 檔案 ($ENV_FILE) 是否存在"
    exit 1
fi

# 清理 .env 的換行符和 BOM---------
sed -i -e 's/\r$//' "$ENV_FILE"
sed -i '1s/^\xEF\xBB\xBF//' "$ENV_FILE"

# 在 while 迴圈之前，加入這段檢查
if [ ! -s "$ENV_FILE" ] || [ -n "$(tail -c1 "$ENV_FILE")" ]; then
    echo "" >> "$ENV_FILE"
fi


# 重新載入 .env，讓後續的腳本能用到最新的 IP
echo "Reloading .env file..."
set -o allexport
source "$ENV_FILE"
set +o allexport

# 驗證環境變數
if [ -z "$HARBOR_USERNAME" ] || [ -z "$HARBOR_PASSWORD" ] || [ -z "$HARBOR_REGISTRY" ]; then
    echo "$ENV_FILE no params USERNAME or PASSWORD"
    exit 1
fi


if [ -z "$S3_END_POINT" ] || [ -z "$S3_BUCKET_NAME" ] ; then
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

# --- [修改部分：更精準的連線判定邏輯] ---
# 1. 取得 Harbor 的域名或 IP 以及 Port
# 如果變數包含冒號(如 192.168.1.1:443)，則提取 Port；否則預設為 443
HARBOR_HOST=$(echo "$HARBOR_REGISTRY" | cut -d':' -f1)
HARBOR_PORT=$(echo "$HARBOR_REGISTRY" | grep -q ':' && echo "$HARBOR_REGISTRY" | cut -d':' -f2 || echo "443")

echo "------------------------------------------"
echo "正在檢查 Harbor 服務連線 ($HARBOR_HOST:$HARBOR_PORT)..."

# 2. 測試連線：使用 /dev/tcp 測試 Port 是否開放，逾時 3 秒
# 這種方式比 ping 準確，因為它模擬的是真實的連線行為
if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$HARBOR_HOST/$HARBOR_PORT" 2>/dev/null; then
    # 網路連線正常：執行登入
    echo "狀態: [連線正常] Harbor 服務響應中。"
    echo "執行: 正在登入 Harbor ($HARBOR_REGISTRY)..."
    
    if echo "$HARBOR_PASSWORD" | docker login "$HARBOR_REGISTRY" -u "$HARBOR_USERNAME" --password-stdin > /dev/null 2>&1; then
        echo "結果: [登入成功] 已建立安全連線。"
    else
        echo "結果: [登入失敗] 帳號密碼驗證失敗，將嘗試使用本地映像檔。"
    fi
else
    # 網路連線失敗或被防火牆攔截
    echo "狀態: [離線模式] 無法建立連線至 $HARBOR_HOST:$HARBOR_PORT。"
    echo "原因: 可能是網路中斷、防火牆阻擋或 Harbor 服務未啟動。"
    echo "結果: 系統將直接啟動本地現有映像檔。"
fi
echo "------------------------------------------"
# --- [修改結束] ---

# 啟動 Docker Compose
echo "Starting Docker Compose..."
docker compose --project-directory "$PROJECT_ROOT" -f "$COMPOSE_FILE" up -d --no-recreate || {
    echo "錯誤: 啟動失敗。若處於離線狀態，請確認本地是否已有下載好的映像檔。"
    exit 1
}

exit 0
