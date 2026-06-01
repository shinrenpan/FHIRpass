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

## 常用指令
```bash
make setup    # 建立所有 Python venv 並安裝依賴
make server   # 啟動中台（port 8000）
make counter  # 啟動 Counter 後端（port 8001）
make dev      # 同時啟動兩個後端
```
