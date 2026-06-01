# FHIRpass 專案說明

## 專案概覽
萬用醫療身分 App，核心解決第三方醫療服務導入的兩大痛點：醫院資安防火牆阻力、個資法合規限制。
採「現場離線建檔 + 遠端線上服務」漸進式雙軌架構。

## 目錄結構
```
FHIRpass/
├── ios/              # Swift iOS App (SwiftUI + SwiftData)
├── shared/           # 共用 Python 工具（QR 編解碼邏輯）
├── server/           # 中台 FastAPI（無狀態醫院路由表）
└── counter/
    ├── backend/      # 掃碼解碼 FastAPI（地端運行，port 8001）
    └── frontend/     # iPad 掃碼 Web 介面（html5-qrcode）
```

## 三軌架構

### 軌道一：離線 QR 建檔（完全不走網路）
- QR 緊湊格式：`身分證|姓名|生日|性別|電話`
- 編碼：UTF-8 → Gzip → Base64 → QR Code，目標 < 100 Bytes
- iOS App 地端加密存檔（SwiftData），中台完全不參與

### 軌道二：SMART on FHIR 線上授權
- iOS `ASWebAuthenticationSession` + OAuth2 + PKCE
- Token 強制鎖入 iOS Keychain（`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`）
- 中台只提供路由表，不經手 Token 與個資
- 測試沙盒：Logica Health FHIR Sandbox

### 軌道三：iPad 掃碼櫃檯模擬
- iPad 瀏覽器用 `html5-qrcode` 掃碼 → POST 緊湊字串至地端 FastAPI（counter/backend）
- 解碼（Base64 → Gzip → 字串）後映射為 TW Core IG Patient JSON
- 網頁即時渲染建檔結果

## TW Core IG Patient 欄位映射
規格：`https://twcore.mohw.gov.tw/ig/twcore/StructureDefinition/Patient-twcore`

| QR 欄位 | FHIR 欄位 |
|---------|-----------|
| 身分證 | `identifier[].value`（system: `http://moi.gov.tw`, code: `NNTWN`）|
| 姓名 | `name[0].text` |
| 生日 | `birthDate`（YYYY-MM-DD）|
| 性別 | `gender`（male/female）|
| 電話 | `telecom[0].value`（system: phone, use: mobile）|

## 中台資料庫
SQLite（MVP），只存醫院路由表，**不存任何個資**。
schema 位於 `server/app/models.py`，表名 `hospital_routing`。

## 開發環境
- Python: 3.11+，使用 venv
- iOS: Xcode 16+、Swift 6、iOS 17+
- 共用解碼邏輯放在 `shared/`，counter/backend 透過 `sys.path` 或 pip editable install 引用

## 已知限制與後續規劃

### 單一使用者（待擴充為多使用者）
目前每個裝置只支援一筆 `PatientProfile`（MVP 合理取捨）。
實際使用情境有多使用者需求（例如父母替嬰兒報到、子女代年邁父母掛號）。

擴充時需要異動：
- `PatientProfile` 加 `isDefault: Bool` 欄位
- `QRCode` Tab 上方加成員 Picker 切換
- `Profile` Tab 改成列表（新增 `ProfileList` Page，原 `Profile` 改名 `ProfileDetail`）
- 新增 Profile 時加**代理聲明 checkbox**（符合個資法：確認已取得被代理人同意或具合法代理權）

### QR 編碼（待加 Gzip 壓縮）
目前格式：緊湊字串 → Base64
目標格式：緊湊字串 → Gzip → Base64（< 100 Bytes）
等 `counter/backend` 解碼端建好後一起實作，確保兩端同步更新。

## 首次設定（clone 後必做）

### 1. Python 虛擬環境
```bash
make setup
```

### 2. Counter SSL 憑證（.pem 不進 repo，需手動產生）
iPad Safari 要求 HTTPS 才能存取相機，憑證放在 `counter/backend/certs/`。
```bash
mkdir -p counter/backend/certs
openssl req -x509 -newkey rsa:2048 \
  -keyout counter/backend/certs/key.pem \
  -out    counter/backend/certs/cert.pem \
  -days 365 -nodes \
  -subj "/CN=fhirpass-counter" \
  -addext "subjectAltName=IP:<你的Mac區網IP>,IP:127.0.0.1"
```
Mac 區網 IP 查詢：`ipconfig getifaddr en0`

iPad Safari 第一次連線會出現「無法驗證憑證」警告，點「繼續前往」即可。

## 常用指令
```bash
make server   # 啟動中台（port 8000，HTTP）
make counter  # 啟動 Counter（port 8001，HTTPS）
make dev      # 同時啟動兩個後端
```

iPad 開啟 Counter：`https://<Mac區網IP>:8001`
