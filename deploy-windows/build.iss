[Setup]
; =========================================
; 1. 軟體基本資訊
; =========================================
AppName=AFS AI Hub
AppVersion=1.0.0
AppPublisher=TWAI
DefaultDirName=C:\AFS-AI-Hub
DefaultGroupName=AFS AI Hub
OutputDir=..\Output
OutputBaseFilename=AFS-AI-Hub-Installer-v1.0.0
Compression=lzma2/ultra64
SolidCompression=yes

; 要求管理員權限 (因為要安裝 OpenSSL 與註冊系統服務)
PrivilegesRequired=admin

[Files]
; ... 其他檔案 ...

; 利用 ..\ 往上層目錄抓取共用的主題，並在安裝時釋放到客戶端的安裝根目錄下
Source: "..\keycloak_theme\*"; DestDir: "{app}\keycloak_theme"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\config\*"; DestDir: "{app}\config"; Flags: ignoreversion recursesubdirs createallsubdirs
; =========================================
; 2. 複製實體檔案到安裝目錄 ({app})
; =========================================
; 複製腳本與設定
Source: "scripts\*"; DestDir: "{app}\scripts"; Flags: ignoreversion recursesubdirs createallsubdirs

; 複製應用程式 JAR 檔
Source: "apps\*"; DestDir: "{app}\apps"; Flags: ignoreversion recursesubdirs createallsubdirs

; 複製所有離線安裝包 (ZIP 與 MSI)
Source: "packages\*"; DestDir: "{app}\packages"; Flags: ignoreversion recursesubdirs createallsubdirs

; 複製設定檔 (config.json)
Source: "config.json"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; 如果你沒有 favicon.ico，建議先註解掉或指向 powershell.exe 自帶圖示
Name: "{commondesktop}\啟動 AFS 服務"; Filename: "powershell.exe"; \
    Parameters: "-WindowStyle Hidden -ExecutionPolicy Bypass -File ""{app}\scripts\start-all.ps1"""; \
    IconFilename: "{app}\apps\favicon.ico"; Check: FileExists(ExpandConstant('{app}\apps\favicon.ico'))

; 更新設備 IP 捷徑 (修正這裡 👇)
Name: "{commondesktop}\更新設備 IP"; Filename: "powershell.exe"; \
    Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\update-config-ip.ps1"""; \
    IconFilename: "{sys}\shell32.dll"; IconIndex: 17

; ===== 更新版本 =====
Name: "{commondesktop}\更新元件版本"; Filename: "powershell.exe"; \
    Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\update-apps.ps1"""; \
    IconFilename: "{sys}\shell32.dll"; IconIndex: 27

; ===== [新增] 快速停止所有服務的捷徑 =====
Name: "{commondesktop}\停止 AFS 服務"; Filename: "powershell.exe"; \
    Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\stop-all.ps1"""; \
    IconFilename: "{sys}\shell32.dll"; IconIndex: 27

[Run]
; =========================================
; 3. 安裝完成後，觸發 PowerShell 進行自動化部署
; =========================================
Filename: "powershell.exe"; \
    Parameters: "-WindowStyle Normal -NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\deploy-all.ps1"""; \
    Description: "正在初始化與啟動 AFS AI Hub 服務 (這可能需要幾分鐘)..."; \
    Flags: waituntilterminated postinstall

[UninstallRun]
; =========================================
; 4. 解除安裝時，觸發清理腳本 (帶入 -Quiet 靜默執行)
; =========================================
Filename: "powershell.exe"; \
    Parameters: "-ExecutionPolicy Bypass -Command ""Set-Location C:\; & '{app}\scripts\uninstall-all.ps1' -Quiet"""; \
    Flags: waituntilterminated; RunOnceId: "UninstallAFSScript"