#!/bin/bash

# 變數定義
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
LOCAL_VM_IP=$(curl -s ifconfig.me)
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yaml"
KEYCLOAK_CONTAINER="keycloak"
KEYCLOAK_URL="https://0.0.0.0:8443"
ROLE_NAME="admin"
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="admin"
CLIENT_ID="ffm"

# 動態取得 VM IP
if [ -n "$LOCAL_VM_IP" ]; then
    VM_IP="$LOCAL_VM_IP"
else
    VM_IP=$(ip addr show | grep -oP 'inet \K[\d.]+(?=/.*eth0)' | head -1 || hostname -I | awk '{print $1}')
fi

if [ -z "$VM_IP" ]; then
    echo "Error: Could not determine VM IP address. Please set LOCAL_VM_IP environment variable."
    exit 1
fi

LOCAL_VM_IP="https://${VM_IP}:80/*"

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
if [ -z "$NEW_USER" ] || [ -z "$NEW_USER_PASSWORD" ] || [ -z "$REALM_NAME"]; then
    echo "$ENV_FILE no params NEW_USER or NEW_USER_PASSWORD or REALM_NAME"
    exit 1
fi

# 取得管理員存取權杖
echo "Obtaining Keycloak admin access token..."
TOKEN_RESPONSE=$(curl -k -s -X POST \
  "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=${ADMIN_USERNAME}" \
  -d "password=${ADMIN_PASSWORD}" \
  -d "grant_type=password")

if [ $? -ne 0 ]; then
    echo "Failed to obtain access token"
    exit 1
fi

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "Failed to parse access token from response: $TOKEN_RESPONSE"
    exit 1
fi

# 創建用戶
echo "Creating new user $NEW_USER in realm $REALM_NAME..."
CREATE_USER_RESPONSE=$(curl -k -s -X POST \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${NEW_USER}\",\"enabled\":true}")

if [ $? -ne 0 ]; then
    echo "Failed to create user $NEW_USER"
    exit 1
fi

# 獲取用戶 ID
echo "Retrieving user ID for $NEW_USER..."
USER_RESPONSE=$(curl -k -s -X GET \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users?username=${NEW_USER}" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

USER_ID=$(echo "$USER_RESPONSE" | jq -r '.[0].id')
if [ -z "$USER_ID" ] || [ "$USER_ID" = "null" ]; then
    echo "Failed to retrieve user ID for $NEW_USER: $USER_RESPONSE"
    exit 1
fi

# 設置用戶密碼
echo "Setting password for user $NEW_USER..."
curl -k -s -X PUT \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users/${USER_ID}/reset-password" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"password\",\"value\":\"${NEW_USER_PASSWORD}\",\"temporary\":false}" || { echo "Failed to set password for user $NEW_USER"; exit 1; }

# 獲取角色 ID
echo "Retrieving role ID for $ROLE_NAME..."
ROLE_RESPONSE=$(curl -k -s -X GET \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/roles/${ROLE_NAME}" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

ROLE_ID=$(echo "$ROLE_RESPONSE" | jq -r '.id')
if [ -z "$ROLE_ID" ] || [ "$ROLE_ID" = "null" ]; then
    echo "Failed to retrieve role ID for $ROLE_NAME: $ROLE_RESPONSE"
    exit 1
fi

# 映射角色
echo "Mapping role $ROLE_NAME to user $NEW_USER in realm $REALM_NAME..."
curl -k -s -X POST \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users/${USER_ID}/role-mappings/realm" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "[{\"id\":\"${ROLE_ID}\",\"name\":\"${ROLE_NAME}\"}]" || { echo "Failed to map role $ROLE_NAME to user $NEW_USER"; exit 1; }

# 取得客戶端 ffm 的內部 ID
echo "Retrieving client ID for $CLIENT_ID in realm $REALM_NAME..."
CLIENT_RESPONSE=$(curl -k -s -X GET \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=${CLIENT_ID}" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

CLIENT_INTERNAL_ID=$(echo "$CLIENT_RESPONSE" | jq -r '.[0].id')
if [ -z "$CLIENT_INTERNAL_ID" ] || [ "$CLIENT_INTERNAL_ID" = "null" ]; then
    echo "Failed to retrieve client ID for $CLIENT_ID: $CLIENT_RESPONSE"
    exit 1
fi

# 更新客戶端 ffm 的 Valid Redirect URIs
echo "Updating Valid Redirect URIs for client $CLIENT_ID to $LOCAL_VM_IP..."
curl -k -s -X PUT \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${CLIENT_INTERNAL_ID}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"redirectUris\":[\"${LOCAL_VM_IP}\"]}" || { echo "Failed to update Valid Redirect URIs for client $CLIENT_ID"; exit 1; }

echo "User $NEW_USER created and role $ROLE_NAME mapped successfully!"
echo "Client $CLIENT_ID updated with Valid Redirect URI $LOCAL_VM_IP!"
echo "Keycloak configuration completed!"