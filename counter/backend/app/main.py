import os
import sys
from pathlib import Path

# shared/ 套件路徑注入
sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel

from shared.qr_codec import decode, to_tw_core_patient

FHIR_SERVER_URL = os.getenv("FHIR_SERVER_URL", "http://localhost:9090/fhir")

app = FastAPI(title="FHIRpass Counter", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 區網內使用，允許所有來源
    allow_methods=["*"],
    allow_headers=["*"],
)


class ScanRequest(BaseModel):
    payload: str  # QR Code 掃到的 Base64 字串


class ScanResponse(BaseModel):
    patient: dict  # TW Core IG Patient JSON
    raw: dict      # 解碼後的原始欄位，供 UI 顯示


class RegisterResponse(BaseModel):
    fhir_id: str   # HAPI FHIR 回傳的 Patient resource ID


@app.post("/scan", response_model=ScanResponse)
def scan(req: ScanRequest):
    try:
        data = decode(req.payload)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    return ScanResponse(
        patient=to_tw_core_patient(data),
        raw={
            "id_number": data.id_number,
            "name": data.name,
            "birthday": data.birthday.strftime("%Y-%m-%d"),
            "gender": "男" if data.gender == "male" else "女",
            "phone": data.phone,
        },
    )


@app.post("/register", response_model=RegisterResponse)
async def register(patient: dict):
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            res = await client.post(
                f"{FHIR_SERVER_URL}/Patient",
                json=patient,
                headers={"Content-Type": "application/fhir+json"},
            )
    except httpx.ConnectError:
        raise HTTPException(status_code=502, detail="無法連線至 FHIR Server")

    if res.status_code != 201:
        raise HTTPException(status_code=502, detail=f"FHIR Server 寫入失敗（{res.status_code}）")

    fhir_id = res.json().get("id")
    if not fhir_id:
        raise HTTPException(status_code=502, detail="FHIR Server 未回傳 Patient ID")

    return RegisterResponse(fhir_id=fhir_id)


@app.get("/health")
def health():
    return {"status": "ok"}


# frontend 靜態檔案（index.html 由根路徑提供）
_frontend = Path(__file__).resolve().parents[2] / "frontend"

@app.get("/")
def index():
    return FileResponse(_frontend / "index.html")
