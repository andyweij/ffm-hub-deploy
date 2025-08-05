#!/bin/bash

# 變數定義
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/init-keycloak.log"
ENV_FILE="$SCRIPT_DIR/config/.env"
LOCAL_VM_IP=$(curl -s ifconfig.me)
KEYCLOAK_CONTAINER="keycloak"
KEYCLOAK_URL="https://0.0.0.0:8443"
ROLE_NAME="admin"
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="admin"
CLIENT_ID="ffm"

exec > >(tee -a "$LOG_FILE") 2>&1

# 動態取得 VM IP
if [ ! -f "$ENV_FILE" ]; then
    echo "未找到 .env 檔案: $ENV_FILE"
    exit 1
fi

sed -i -e 's/\r$//' $ENV_FILE

# 從 .env 檔案載入環境變數
set -o allexport
source "$ENV_FILE"
set +o allexport

if [ -z "$VM_IP" ]; then
    echo "Error: Could not determine VM IP address. Please set LOCAL_VM_IP environment variable."
    exit 1
fi

LOCAL_VM_IP="https://${VM_IP}/*"


# 驗證環境變數
if [ -z "$NEW_USER" ] || [ -z "$NEW_USER_PASSWORD" ] || [ -z "$REALM_NAME" ] || [ -z "$VM_IP" ]; then
    echo "$ENV_FILE no params NEW_USER or NEW_USER_PASSWORD or REALM_NAME or VM_IP"
    exit 1
fi

echo "Checking Keycloak health..."
MAX_WAIT=120
WAIT_COUNT=0
until curl -k -s -f "http://localhost:8443/q/health/live" >/dev/null; do
    CURL_EXIT_CODE=$?
    if [ $CURL_EXIT_CODE -eq 52 ]; then
        echo "assuming Keycloak is ready"
        break
    elif [ $CURL_EXIT_CODE -eq 56 ]; then
        echo "Keycloak is not ready yet (code 56: Connection reset by peer), retrying..."
    else
        echo "Unexpected curl error (code $CURL_EXIT_CODE)"
        echo "Keycloak container logs:"
        docker logs "$KEYCLOAK_CONTAINER"
        exit 1
    fi
    sleep 10
    WAIT_COUNT=$((WAIT_COUNT + 2))
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo "Keycloak health check timed out"
        echo "Keycloak container logs:"
        docker logs "$KEYCLOAK_CONTAINER"
        exit 1
    fi
done
echo "Keycloak health check passed"

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

# TERMS_AND_CONDITIONS
echo "Enabling Terms and Conditions required action for realm $REALM_NAME..."
curl -k -s -X PUT \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/authentication/required-actions/TERMS_AND_CONDITIONS" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
        "alias": "TERMS_AND_CONDITIONS",
        "name": "Terms and Conditions",
        "providerId": "TERMS_AND_CONDITIONS",
        "enabled": true,
        "defaultAction": true,
        "priority": 20, 
		"config": {}
  }' || { echo "Failed to enable Terms and Conditions"; exit 1; }
echo "Terms and Conditions set as default action for new users."

# 創建用戶
echo "Creating new user $NEW_USER in realm $REALM_NAME..."

USER_PAYLOAD=$(cat <<EOF
{
  "username": "${NEW_USER}",
  "enabled": true,
  "requiredActions": ["terms_and_conditions"]
}
EOF
)

CREATE_USER_RESPONSE=$(curl -k -s -X POST \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$USER_PAYLOAD")

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
echo "User $NEW_USER created and role $ROLE_NAME mapped successfully!"
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
echo "Client $CLIENT_ID updated with Valid Redirect URI $LOCAL_VM_IP!"

echo "Client $CLIENT_ID updated with Valid Redirect URI $LOCAL_VM_IP!"

# 更新 Realm 的登入主題
echo "Updating login theme for realm $REALM_NAME to AIPORTAL-THEME..."
REALM_CONFIG_RESPONSE=$(curl -k -s -X GET \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

if [ -z "$REALM_CONFIG_RESPONSE" ] || [ "$REALM_CONFIG_RESPONSE" = "null" ]; then
    echo "Failed to retrieve realm configuration for $REALM_NAME"
    exit 1
fi

# 更新 loginTheme 欄位
UPDATED_REALM_CONFIG=$(echo "$REALM_CONFIG_RESPONSE" | jq '.loginTheme = "aiportal-theme"')

# PUT 更新 Realm 設定
curl -k -s -X PUT \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$UPDATED_REALM_CONFIG" || { echo "Failed to update login theme for realm $REALM_NAME"; exit 1; }

echo "Login theme for realm $REALM_NAME set to AIPORTAL-THEME successfully!"

# 設定 Realm 的語系
echo "Updating realm $REALM_NAME with supported locales and default locale (zhtw)..."
REALM_LOCALE_CONFIG=$(echo "$REALM_CONFIG_RESPONSE" | \
  jq '.internationalizationEnabled = true | .supportedLocales = ["zhtw"] | .defaultLocale = "zhtw"')

curl -k -s -X PUT \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$REALM_LOCALE_CONFIG" || { echo "Failed to update locales for realm $REALM_NAME"; exit 1; }

echo "Realm $REALM_NAME updated with supported locale and default locale set to zhtw."

echo "Keycloak configuration is complete! Please try to visit https://${VM_IP}"