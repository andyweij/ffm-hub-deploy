#!/bin/bash
set -e

# 容器對應表（手動維護的）
declare -A IMAGE_TO_CONTAINER_NAMES=(
  ["ffm-hub/api-relay"]="api-relay"
  ["ffm-hub/aiportal"]="aiportal"
  ["keycloak"]="keycloak"
  ["postgres"]="afs-ai-hub-db"
  ["prom/prometheus"]="afs-ai-hub-prometheus"
  ["grafana/grafana"]="afs-ai-hub-grafana"
)

# 保護模組 image（刪除失敗就跳過）
PROTECTED_IMAGES=("keycloak" "postgres" "prom/prometheus" "grafana/grafana")

echo "收集與 AFS-AI-HUB 及 vLLM 相關的 image 資訊..."

# 找出所有相關 image（手動與 vllm）
IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep -Ei 'afs-ai-hub|keycloak|postgres|prom/prometheus|grafana/grafana|vllm')

if [ -z "$IMAGES" ]; then
  echo "沒有找到任何相關 image"
  exit 0
fi

echo "以下 image 將進行刪除處理（保護模組失敗則略過）："
echo "$IMAGES" | awk '{printf "  - %s (%s)\n", $1, $2}'

read -p "是否要繼續進行刪除？(y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "操作取消"
  exit 0
fi

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

# 然後再逐個 image 嘗試刪除
while read -r entry; do
  IMAGE_TAG=$(echo "$entry" | awk '{print $1}')
  IMAGE_ID=$(echo "$entry" | awk '{print $2}')
  echo "處理 image: $IMAGE_TAG ($IMAGE_ID)"

  echo "🧹嘗試移除 image $IMAGE_TAG"
  if docker rmi -f "$IMAGE_ID" 2>/dev/null; then
    echo "image $IMAGE_TAG 已成功刪除"
  else
    if printf '%s\n' "${PROTECTED_IMAGES[@]}" | grep -q "^$IMAGE_TAG$"; then
      echo "$IMAGE_TAG 為保護模組，刪除失敗略過"
    else
      echo "image $IMAGE_TAG 刪除失敗，請手動處理"
    fi
  fi
done <<< "$IMAGES"

# Volume 清除（可選）
docker volume rm deploy_keycloak_db || true

echo "✅ AFS-AI-HUB 及 vLLM 容器與 image 清理作業完成"
