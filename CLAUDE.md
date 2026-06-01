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
- QR 緊湊格式：`身分證|姓名|生日(YYYYMMDD)|性別(M/F)|電話`
- 編碼：UTF-8 → zlib 壓縮 → Base64
- iOS App 地端加密存檔（SwiftData），中台完全不參與

### 軌道二：SMART on FHIR 線上授權
- iOS `ASWebAuthenticationSession` + OAuth2 + PKCE
- Token 強制鎖入 iOS Keychain（`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`）
- 中台只提供路由表，不經手 Token 與個資
- 測試沙盒：本地 SMART Dev Sandbox（Docker，見下方）

### 軌道三：iPad 掃碼櫃檯模擬
- iPad 瀏覽器用 `html5-qrcode` 掃碼 → POST 緊湊字串至地端 FastAPI（counter/backend）
- 解碼（Base64 → 字串）後映射為 TW Core IG Patient JSON
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

## 端對端整合測試架構

使用本地 **SMART Dev Sandbox**（`make sandbox`）：

| 服務 | 角色 | URL |
|------|------|-----|
| `hapiproject/hapi` + TW Core IG | 醫院 FHIR Server | `http://localhost:9090/fhir` |
| `smartonfhir/smart-launcher-2` | OAuth2 + FHIR Proxy | `http://localhost:9091` |

iOS App 連接的 FHIR base URL 是 Launcher proxy：`http://localhost:9091/v/r4/fhir`

```
軌道一：Counter 掃 QR
  → 解碼病人資料
  → POST Patient 到 http://localhost:9090/fhir/Patient
  → 取得 Patient FHIR ID

軌道二：iOS App OAuth2 登入（經 Launcher port 9091）
  → Launcher 列出沙盒內所有 Patient（含剛 POST 的）
  → 病患選取自己 → token.patient = 該 FHIR ID
  → 呼叫 FHIR API 讀取同一筆病歷
```

> seed URL 使用 `localhost`，僅適用於 iOS Simulator。
> 實機測試需將 `localhost` 改為 Mac 區網 IP（`ipconfig getifaddr en0`）。

seed 變更後需重設：`make sandbox-reset`（清除 Docker volume + `server/fhirpass.db`）

## 中台資料庫
SQLite（MVP），只存醫院路由表，**不存任何個資**。
`server/app/models.py` → `HospitalRouting`（表名 `hospital_routing`）。
首次啟動時自動建表，並 seed 一筆 `DEV_SANDBOX`（本地開發沙盒）。

## 開發環境
- Python: 3.11+，使用 venv
- iOS: Xcode 16+、Swift 6、iOS 17+
- 共用解碼邏輯放在 `shared/`，counter/backend 以 `sys.path` 注入引用
- iOS 專案開啟：`open ios/FHIRpass.xcodeproj`
- iOS 專案設定修改後需重跑：`cd ios && xcodegen generate`

## 已知限制與後續規劃

### 單一使用者（待擴充為多使用者）
目前每個裝置只支援一筆 `PatientProfile`（MVP 合理取捨）。
實際使用情境有多使用者需求（例如父母替嬰兒報到、子女代年邁父母掛號）。

擴充時需要異動：
- `PatientProfile` 加 `isDefault: Bool` 欄位
- `QRCode` Tab 上方加成員 Picker 切換
- `Profile` Tab 改成列表（新增 `ProfileList` Page，原 `Profile` 改名 `ProfileDetail`）
- 新增 Profile 時加**代理聲明 checkbox**（符合個資法：確認已取得被代理人同意或具合法代理權）

### Deeplink（待實作）
`Deeplink.swift` 目前 `init?` 永遠回傳 `nil`（無已實作的 case）。
待 AppContainer 設計完成後，在此加入 case 並實作 `makeHostController()`。

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
make setup    # 建立所有 Python venv 並安裝依賴
make server   # 啟動中台（port 8000，HTTP）
make counter  # 啟動 Counter（port 8001，HTTPS）
make dev      # 同時啟動 server（背景）與 counter
```

iPad 開啟 Counter：`https://<Mac區網IP>:8001`
