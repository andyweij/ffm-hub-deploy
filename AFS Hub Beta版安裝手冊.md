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

- [`deploy-step1.sh`](#####7-執行安裝步驟1安裝相關需求依賴)：安裝相依函式庫及工具  
- [`deploy-step2.sh`](####10-執行安裝步驟2)：部署主要系統與初始化帳號管理系統Keycloak
---
##### 1. 架設完成Ubuntu 22.04 伺服器，並將壓縮檔放至要安裝的目錄。
![image](https://hackmd.io/_uploads/Bk_J6rLLxg.png)

##### 2. 若Linux系統無解壓縮工具需再另外安裝，安裝指令如下：
```bash
sudo apt install unzip
```
![image](https://hackmd.io/_uploads/HyyviVGUel.png)

##### 3. 依以下指令解壓縮afs-hub-installer：
```bash
unzip "afs-hub-installer-v0.3.0.zip" -d .
```
![image](https://hackmd.io/_uploads/SkmFoEMUel.png)

##### 4. 您會透過郵件的方式收到 S3_secret.zip 的檔案，請下載解壓縮後將該檔案放到以下目錄位置：
```bash
${解壓縮afs-hub-installer目錄路徑}/afs-hub-installer/deploy/config
```
![image](https://hackmd.io/_uploads/Bk3OoH8Lle.png)

##### 5. 切換至安裝資料夾的父目錄，指令如下：
```bash
cd ${解壓縮afs-hub-installer目錄路徑}
```
![image](https://hackmd.io/_uploads/Hy7MFyTLxe.png)
![image](https://hackmd.io/_uploads/Syi88_xvlg.png)

##### 6. 賦予執行權限，指令如下：
```bash
sudo chmod 775 -R afs-hub-installer/ 
find afs-hub-installer/deploy/ -maxdepth 1 -name "*.sh" -exec sed -i -e 's/\r$//' {} \;
```
![image](https://hackmd.io/_uploads/B1BcL_xDxl.png)

##### 7. 切換至目錄deploy，指令如下：
```bash
cd ${解壓縮afs-hub-installer目錄路徑}/afs-hub-installer/deploy/
```
![螢幕擷取畫面 2025-07-25 100840](https://hackmd.io/_uploads/ryNBvDevlg.png)



##### 8. 執行安裝步驟1，請輸入以下指令安裝相依函式庫及工具，此步驟約需要約3至5分鐘。
```bash
./deploy-step1.sh
```
![image](https://hackmd.io/_uploads/BJ9Wduxweg.png)

##### 9. 安裝步驟1完成會看到以下畫面，系統將自動重啟。若使用VM安裝，請重新連線。
![image](https://hackmd.io/_uploads/SyiBdOeveg.png)


##### 10. 再次切換至目錄deploy，指令如下：
```bash
cd ${解壓縮afs-hub-installer目錄路徑}/afs-hub-installer/deploy/ 
```
![image](https://hackmd.io/_uploads/Hy1aOOgDge.png)

##### 11. 執行安裝步驟2，請輸入以下指令部署主要系統與初始化Keycloak，此步驟約需要約3至5分鐘。
```bash
./deploy-step2.sh 
```
![image](https://hackmd.io/_uploads/S10gKOgwex.png)


##### 12. 執行安裝步驟2的過程中會自動初始化AFS Hub所使用的帳號管理系統Keycloak(init-keycloak.sh)，請等待系統初始化成功。
![image](https://hackmd.io/_uploads/H14gsPePee.png)



##### 13. 安裝完成後會看到以下訊息，請複製紅框網址開啟網頁測試。
![image](https://hackmd.io/_uploads/BySqovgDex.png)




## 驗證安裝
1. 將網址複製至瀏覽器後，如有部署成功，即會看到AFS Hub登入畫面。
![image](https://hackmd.io/_uploads/ryR53vlDee.png)
2. 安裝後初始登入，請輸入預設帳號及密碼 **ffm-admin**，點選登入。
![image](https://hackmd.io/_uploads/SJoa3Plwlx.png)
3. 進入歡迎頁面，請詳閱AFS Hub使用條款後點擊【開始使用】。
![螢幕擷取畫面 2025-07-25 103256](https://hackmd.io/_uploads/rJWepwePgx.png)
4. 初始登入請更新您的帳號資訊，點選提交。
![image](https://hackmd.io/_uploads/Bkq3VJhEll.png)
5. 登入至AFS Hub首頁，即成功完成安裝驗證。
![image](https://hackmd.io/_uploads/Hkp79Ogwxl.png)
6. 可至 [AFS Hub Beta版說明文件](https://hackmd.io/@afshub/user-manual) [平台管理操作說明](https://hackmd.io/gapD7WyATqGBJJePSrXItg?view#%E5%B9%B3%E5%8F%B0%E7%AE%A1%E7%90%86%E6%93%8D%E4%BD%9C%E8%AA%AA%E6%98%8E) 開始新增使用者及下載模型。

## 移除軟體
1. 切換至目錄deploy，指令如下：
```bash
cd ${解壓縮afs-hub-installer目錄路徑}/afs-hub-installer/deploy/
```
![螢幕擷取畫面 2025-07-25 100840](https://hackmd.io/_uploads/ryNBvDevlg.png)

2. 清除docker container，指令如下：
```
./uninstall-afs-hub-service.sh
```
![image](https://hackmd.io/_uploads/B1J_lngPeg.png)

3. 系統會詢問「是否要繼續進行刪除？(y/n)」，輸入 **y** 繼續。

![image](https://hackmd.io/_uploads/ByZxZ3gDlg.png)

4. 完成清除docker container後看到以下畫面。

![image](https://hackmd.io/_uploads/r1edYIGUxx.png)

5. 移除部署afs-hub相關工具，指令如下：
```
./uninstall.sh
```
![image](https://hackmd.io/_uploads/Sy4uZnewxx.png)

6. 完成清除afs-hub相關工具後看到以下畫面。

![image](https://hackmd.io/_uploads/BywiKLGIxl.png)

7. 從目錄中刪除afs-hub-installer及壓縮檔。

![image](https://hackmd.io/_uploads/BySIOhlwxl.png)

8. 刪除後，目錄中已完全移除afs-hub-installer相關檔案。

![image](https://hackmd.io/_uploads/Hyu7_TxDxx.png)



## 常見問題

Q. **如遇到Harbor下載Image失敗，如何處理？**  
A. 請直接重新再執行一次 **第11點：安裝步驟2**。  

Q. **如遇到Keycloak執行安裝出錯，如何處理？**  
A. 請再次手動執行Keycloak。
```
./init-keycloak.sh
```
![image](https://hackmd.io/_uploads/r1DxCqmUex.png)

Q. **若是透過雲端VM安裝AFS Hub，需要設定安全性群組嗎？**  
A. 需設置安全性群組，並新增keycloak使用port:8443。
![image](https://hackmd.io/_uploads/rk6q1c7Lgx.png) 

Q. **若是透過雲端VM安裝AFS Hub，需要使用靜態IP媽？**  
A. 需要使用靜態IP，如使用浮動IP，VM重啟後無法使用。


