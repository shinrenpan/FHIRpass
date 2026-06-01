import sys
from pathlib import Path

# shared/ 套件路徑注入
sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel

from shared.qr_codec import decode, to_tw_core_patient

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


@app.get("/health")
def health():
    return {"status": "ok"}


# frontend 靜態檔案（index.html 由根路徑提供）
_frontend = Path(__file__).resolve().parents[2] / "frontend"

@app.get("/")
def index():
    return FileResponse(_frontend / "index.html")

