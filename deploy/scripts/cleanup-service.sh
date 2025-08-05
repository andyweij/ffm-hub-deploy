#!/bin/bash
# cleanup-service.sh

set -e
echo "Cleaning up deployment service: $1"

# $1 會接收從 service 檔案傳入的服務名稱
SERVICE_NAME=$1

# 停用並移除指定的服務
sudo systemctl disable "$SERVICE_NAME"
sudo rm "/etc/systemd/system/$SERVICE_NAME"
sudo systemctl daemon-reload

echo "Service $SERVICE_NAME cleaned up successfully."