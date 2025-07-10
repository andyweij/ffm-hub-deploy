# 軟體名稱安裝手冊

## 目錄
- [系統需求](#系統需求)
- [安裝方式](#安裝方式)
- [常見問題](#常見問題)

---

## 系統需求

- 作業系統：Ubuntu 22.04

---

## 安裝方式

0. 架設完成Ubuntu 22.04 伺服器
1. 將壓縮檔解壓縮至要部署的設備上
2. 賦予執行權限
   ``` sudo chmod 775 -R ffm-hub-installer/ ```
3. 切換至目錄deploy
```cd ffm-hub-installer/deploy/ ```
4. 執行部署步驟1(安裝相關需求依賴)
```./deploy-step1.sh```

5. 安裝後，等待系統重啟後。
6. 建立服務自簽憑證
```./gen-all-cert.sh```

7. 執行部屬步驟2
```./deploy-step2.sh ```
8. 自動初始化keycloak(init-keycloak.sh)；完成後會看到以下訊息，並複製網址即可開網頁測試。


## 常見問題
- harbor下載IMAGE失敗，直接重新在執行一次步驟7
- keycloak執行步驟3出錯，請手動執行步驟8
