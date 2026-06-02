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
├── sandbox/          # 本地開發沙盒（Docker Compose）
│   └── hapi/         # HAPI FHIR 設定（含 TW Core IG）
└── counter/
    ├── backend/      # 掃碼 + FHIR 寫入 FastAPI（地端運行，port 8001）
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

#### 多角色授權設計原則
- **授權不限病患**：醫護人員（醫生、護理師、行政）走相同 OAuth2 架構，以 scope 區分角色
  - 病患端：`Patient Launch`（`launch/patient`，token 帶 `patient` claim）
  - 醫護端：`EHR Launch`（`launch`，token 帶 `encounter` / 人員身份 claim）
- **每院獨立授權**：各醫院各自核發 token，互不通用；App 對每家醫院分開儲存 Keychain 憑證
- **跨院整合是中台責任**：App 層只對單一醫院授權，跨院資料聚合由中台處理，不在 App 實作

### 軌道三：iPad 掃碼櫃檯（真實 FHIR 寫入）
- iPad 瀏覽器用 `html5-qrcode` 掃碼 → POST 緊湊字串至地端 FastAPI（counter/backend）
- 解碼後先以身分證號搜尋 HAPI FHIR（`GET /Patient?identifier=...`）
  - **既有病患**：直接顯示病患資料 + 歷史預約（`GET /Appointment?patient={id}`），不重複建立
  - **新病患**：顯示解碼預覽 → 確認後 POST Patient 至 HAPI FHIR（`POST /Patient`），取得 FHIR ID
- Counter 直連 HAPI（`http://localhost:9090/fhir`），繞過 OAuth，模擬醫院 admin 角色
- iOS App OAuth2 連線後可讀取 Counter 已寫入的同一筆 Patient 資料，完成跨軌閉環

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

iOS App 連接的 FHIR base URL 是 Launcher proxy，並帶有 sim config：

```
http://localhost:9091/v/r4/sim/{sim}/fhir
```

### SMART Launcher Sim Config

Launcher 透過 URL 路徑中的 Base64 sim config 決定授權流程。`server/app/main.py` seed 中使用：

```
sim = [3,"","","AUTO",0,0,0,"","","","","","","",0,1,""]
```

各欄位說明（關鍵欄位）：
- `t[0] = 3` → `patient-standalone`（病患直接授權，不需醫護人員登入）
- `t[1] = ""` → 顯示 Patient picker，讓病患自選
- `t[4] = 0` → `skip_login = false`（顯示登入/選取步驟）
- `t[5] = 0` → `skip_auth = false`（顯示 scope 確認頁）
- `t[15] = 1` → `pkce = auto`

> 若改為 `t[0] = 2`（provider-standalone）會顯示 Practitioner Login 且因無醫護資料而卡住。

### 端對端 Demo 流程

**準備**：`make sandbox`（等 HAPI 完全啟動後再繼續）→ `make dev`

**軌道三：Counter 建檔**
1. 瀏覽器開 `https://localhost:8001`
2. 掃描 iOS App QR Code → Counter 以身分證號搜尋 HAPI
3. 新病患：顯示解碼結果 → 點「確認建檔」→ `POST /Patient` 寫入 HAPI → 取得 FHIR ID

**軌道二：iOS OAuth2 授權**
4. iOS App → Hospitals Tab → 本地開發沙盒 → 連結此醫院帳號
5. Launcher 彈出 Patient Login → 下拉選取病患（即剛建檔的那筆）→ 輸入任意密碼 → Login
6. Scope 確認頁 → Allow → 授權成功，token 帶 `patient = FHIR ID`

**閉環驗證（可選）**
7. iOS App 點「線上預約掛號」→ 寫入 Appointment 至 HAPI
8. Counter 重新掃碼 → 搜尋到既有病患 → 顯示剛寫入的預約記錄

**重設**：`make sandbox-reset`（清除所有 HAPI 資料 + server DB，從頭再跑）

> seed URL 使用 `localhost`，僅適用於 iOS Simulator。
> 實機測試需將 `localhost` 改為 Mac 區網 IP（`ipconfig getifaddr en0`）。

### 已知相容性修正

| 問題 | 修正位置 | 說明 |
|------|---------|------|
| iOS QR zlib 格式 | `shared/qr_codec.py` | `NSData.compressed(using: .zlib)` 可能產生 raw deflate，加 `wbits=-15` fallback |
| SMART `aud` 參數 | `ios/Sources/Shared/SMARTAuth.swift` | SMART 規格必要欄位，授權 URL 需帶 `aud=fhirBaseURL` |
| Launcher 病患姓名空白 | `shared/qr_codec.py` | Launcher 需 `name.family`/`name.given`，TW Core IG 只有 `name.text` 不夠 |

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
make setup          # 建立所有 Python venv 並安裝依賴
make server         # 啟動中台（port 8000，HTTP）
make counter        # 啟動 Counter（port 8001，HTTPS），自動帶 FHIR_SERVER_URL=localhost:9090
make dev            # 同時啟動 server（背景）與 counter
make sandbox        # 啟動本地 SMART Dev Sandbox（Docker，HAPI 9090 + Launcher 9091）
make sandbox-down   # 停止 sandbox container
make sandbox-reset  # 清除 sandbox volume 並刪除 server/fhirpass.db（重設所有資料）
```

iPad 開啟 Counter：`https://<Mac區網IP>:8001`

> `make counter` 預設連 `http://localhost:9090/fhir`（HAPI 直連，無 OAuth）。
> 實機 iPad 測試時，Counter 本身也需要改用 Mac 區網 IP。
