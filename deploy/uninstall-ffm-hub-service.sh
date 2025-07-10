#!/bin/bash

set -e

docker stop api-relay

docker rm api-relay

docker stop aiportal

docker rm aiportal

docker stop keycloak

docker rm keycloak

docker stop ffm-hub-db

docker rm ffm-hub-db

docker volume rm deploy_keycloak_db

echo "尋找包含 'vllm' 的 Docker image..."

# 找出所有包含 vllm 關鍵字的 image（repository 或 tag 中）
IMAGE_IDS=$(docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep -i vllm | awk '{print $2}' | sort -u)

if [ -z "$IMAGE_IDS" ]; then
    echo "沒有找到任何與 vllm 相關的 image"
    exit 0
fi

echo "以下 image 將被移除："
docker images --format "  - {{.Repository}}:{{.Tag}} ({{.ID}})" | grep -i vllm

# 確認移除
read -p "是否要刪除這些 images？(y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "操作取消"
    exit 0
fi

# 逐一移除
for image_id in $IMAGE_IDS; do
    echo "移除 image ID：$image_id"
    docker rmi -f "$image_id"
done

echo "vLLM 相關 image 移除完成"
