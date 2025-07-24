---
title: AFS Hub Beta版安裝手冊

---

# AFS Hub Beta版安裝手冊

## 系統需求

### 系統需求表
| 項目 | 需求 |
|-------|-----|
| 作業系統 | 僅支援 Ubuntu 22.04 |
| CPU | 最低Intel i5，推薦Intel i7 含以上 |
| Memory | 最低16GB，推薦32GB |
| Storage | 建議預留 200 GB<br>1. 模型大小：約 55 GB<br>- Llama3.1-FFM-8B：16.07 GB<br>- Llama3.2-FFM-11B：21.35 GB<br>- Qwen3-4B：16.12 GB<br>2. 應用程式：約 45 GB<br>3. 資料庫：預留約 100 GB |
| GPU | 1. 最小需求記憶體請見[模型對應GPU規格](#模型對應GPU規格)<br>2.GPU需支援vLLM版本號請見[模型對應GPU規格](#模型對應GPU規格)<br>3. FFM Hub Beta版僅支援單顆GPU佈署|


### 模型對應GPU規格
| 模型 | GPU最小需求記憶體 | GPU需支援vLLM版本號 |
|-------|:-----:|:-----:|
| Llama3.1-FFM-8B | 20 GB | v0.8.0 |
| Llama3.2-FFM-11B | 27 GB | v0.8.0 |
| Qwen3-4B |  13 GB | v0.9.0 |

---
## 安裝環境
雲端VM安裝AFS Hub時，需設置安全性群組，詳情請見[常見問題](#常見問題)

## 安裝方式
本安裝流程已封裝成兩個簡單的指令腳本，只需依序執行以下兩個 script 即可完成整體安裝：

- [`deploy-step1.sh`](#####7-執行安裝步驟1安裝相關需求依賴)：安裝必要依賴與前置設定  
- [`deploy-step2.sh`](####10-執行安裝步驟2)：部署主要系統與初始化 Keycloak
---
##### 1. 架設完成Ubuntu 22.04 伺服器，並將壓縮檔放至要安裝的目錄
![image](https://hackmd.io/_uploads/Bk_J6rLLxg.png)

##### 2. 若Linux系統無解壓縮工具需再另外安裝，安裝指令如下
```bash
sudo apt install unzip
```
![image](https://hackmd.io/_uploads/HyyviVGUel.png)

##### 3. 解壓縮installer
```bash
unzip "afs-hub-installer-v0.3.0.zip" -d .
```
![image](https://hackmd.io/_uploads/SkmFoEMUel.png)

##### 4. 將S3_secret.txt 放到以下位置
```bash
${解壓縮afs-hub-installer目錄路徑}/afs-hub-installer/deploy/config
```
![image](https://hackmd.io/_uploads/Bk3OoH8Lle.png)

##### 5. 賦予執行權限
```bash
sudo chmod 775 -R afs-hub-installer/ 
find afs-hub-installer/deploy/ -maxdepth 1 -name "*.sh" -exec sed -i -e 's/\r$//' {} \;
```
##### 6. 切換至目錄deploy
```bash
cd ${解壓縮afs-hub-installer目錄路徑}/afs-hub-installer/deploy/
```
##### 7. 執行安裝步驟1(安裝相關需求依賴)
```bash
./deploy-step1.sh
```
![image](https://hackmd.io/_uploads/S1VTbpoHxx.png)
##### 8. 安裝結束，等待系統重啟。
##### 9. 再次切換至目錄deploy
```bash
cd ${解壓縮afs-hub-installer目錄路徑}/afs-hub-installer/deploy/ 
```
##### 10. 執行安裝步驟2
```bash
./deploy-step2.sh 
```

11. 自動初始化keycloak(init-keycloak.sh)；完成後會看到以下訊息，並複製網址即可開網頁測試。
![image](https://hackmd.io/_uploads/SJAHQajSlx.png)



## 驗證安裝
1. 將網址複製至瀏覽器後，如有部署成功，即會看到AFS Hub登入畫面。
![image](https://hackmd.io/_uploads/ryjfOonSxg.png)
2. 安裝後初始登入，請輸入預設帳號及密碼 **ffm-admin**，點選登入。
![image](https://hackmd.io/_uploads/B183By3Nel.png)
3. 初始登入請更新您的帳號資訊，點選提交。
![image](https://hackmd.io/_uploads/Bkq3VJhEll.png)
4. 進入歡迎頁面，請詳閱AFS Hub使用條款後點擊【開始使用】。
![HUB條款](https://hackmd.io/_uploads/rJCf6t7Uex.jpg)
5. 登入至AFS Hub首頁，即成功完成安裝驗證。
![image](https://hackmd.io/_uploads/S1a4tinrex.png)
6. 可至 [AFS Hub Beta版說明文件](https://hackmd.io/@ffmhub/user-manual) [平台管理操作說明](https://hackmd.io/gapD7WyATqGBJJePSrXItg?view#%E5%B9%B3%E5%8F%B0%E7%AE%A1%E7%90%86%E6%93%8D%E4%BD%9C%E8%AA%AA%E6%98%8E) 開始新增使用者及下載模型。

## 移除軟體
1. 清除docker container
```
./uninstall-afs-hub-service.sh
```
![image](https://hackmd.io/_uploads/r1edYIGUxx.png)
2. 移除部署afs-hub相關工具
```
./uninstall.sh
```
![image](https://hackmd.io/_uploads/BywiKLGIxl.png)
## 常見問題
- harbor下載IMAGE失敗，直接重新再執行一次安裝步驟1 (第7點)
- keycloak執行安裝步驟2出錯，請再次手動執行安裝步驟2 (第11點)
![image](https://hackmd.io/_uploads/r1DxCqmUex.png)
- 若是透過雲端VM安裝AFS Hub，需設置安全性群組，並開啟keycloak使用port:8443。
![image](https://hackmd.io/_uploads/rk6q1c7Lgx.png)


