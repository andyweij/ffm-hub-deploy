#!/bin/bash
# 如果任何一個指令失敗，就立刻終止腳本
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="${PROJECT_ROOT}/scripts"
CONFIG_DIR="${PROJECT_ROOT}/config"

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
  ["postgres"]="afs-hub-db"
  ["prom/prometheus"]="afs-hub-prometheus"
  ["grafana/grafana"]="afs-hub-grafana"
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

echo "--- [$(date)] --- Starting  re deploy all service"
bash "${SCRIPT_DIR}/deploy-all.sh"