#!/bin/bash
# 如果任何一個指令失敗，就立刻終止腳本
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="${PROJECT_ROOT}/scripts"
CONFIG_DIR="${PROJECT_ROOT}/config"
ENV_FILE="${PROJECT_ROOT}/.env"

#-----------Log--------
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/redeploy.log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

# 容器對應表（手動維護的）
declare -A IMAGE_TO_CONTAINER_NAMES=(
  ["ffm-hub/api-relay"]="api-relay"
  ["ffm-hub/aiportal"]="aiportal"
  ["keycloak"]="keycloak"
  ["postgres"]="afs-ai-hub-db"
  ["prom/prometheus"]="afs-ai-hub-prometheus"
  ["grafana/grafana"]="afs-ai-hub-grafana"
)

echo "開始處理..."

# 先停止並移除所有手動定義的容器
for key in "${!IMAGE_TO_CONTAINER_NAMES[@]}"; do
  cname="${IMAGE_TO_CONTAINER_NAMES[$key]}"
  echo "停止並刪除容器：$cname"
  docker stop "$cname" 2>/dev/null || true
  docker rm "$cname" 2>/dev/null || true
done

# 尋找所有與 vllm 有關的 container 並移除
echo "尋找 vLLM 相關容器..."
VLLM_CONTAINERS=$(docker ps -a --filter "ancestor=$(docker images | grep -i vllm | awk '{print $3}')" --format "{{.ID}}")
for cid in $VLLM_CONTAINERS; do
  echo "停止並刪除 vLLM 容器：$cid"
  docker stop "$cid" 2>/dev/null || true
  docker rm "$cid" 2>/dev/null || true
done

# 預設 IP 取得方式
IP_METHOD="local"

# 解析傳入的參數
if [[ "$1" == "--local-ip" ]]; then
  IP_METHOD="local"
  echo "將使用本地 IP 取得方式。"
elif [[ "$1" == "--public-ip" ]]; then
  IP_METHOD="public"
  echo "將使用公開 IP 取得方式。"
fi

# 將選擇的 IP 方式寫入 .env 檔案
# 檢查 .env 中是否「存在」 IP_ACQUISITION_METHOD 這一行
if grep -q "^IP_ACQUISITION_METHOD=" "$ENV_FILE"; then
    # 如果存在，就用 sed 取代
    sed -i "s/^IP_ACQUISITION_METHOD=.*/IP_ACQUISITION_METHOD=${IP_METHOD}/" "$ENV_FILE"
    echo "已更新 .env 中的 IP_ACQUISITION_METHOD 為：${IP_METHOD}"
else
    # 如果不存在，就用 echo 新增
    echo "" >> "$ENV_FILE"
    echo "IP_ACQUISITION_METHOD=${IP_METHOD}" >> "$ENV_FILE"
    echo "已新增 IP_ACQUISITION_METHOD 至 .env：${IP_METHOD}"
fi

echo "--- [$(date)] --- Starting  re deploy all service"
bash "${SCRIPT_DIR}/deploy-all.sh"