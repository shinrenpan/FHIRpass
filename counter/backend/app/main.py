import os
import sys
from pathlib import Path

# shared/ 套件路徑注入
sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

import httpx
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel

from shared.qr_codec import decode, to_tw_core_patient

FHIR_SERVER_URL = os.getenv("FHIR_SERVER_URL", "http://localhost:9090/fhir")

app = FastAPI(title="FHIRpass Counter", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class ScanRequest(BaseModel):
    payload: str


class ScanResponse(BaseModel):
    patient: dict
    raw: dict


class RegisterResponse(BaseModel):
    fhir_id: str


class PatientSearchResponse(BaseModel):
    fhir_id: str
    patient: dict


class AppointmentItem(BaseModel):
    id: str
    status: str
    start: str | None
    description: str


class AppointmentsResponse(BaseModel):
    appointments: list[AppointmentItem]


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


@app.get("/patients/search", response_model=PatientSearchResponse)
async def search_patient(identifier: str = Query(..., description="台灣身分證號")):
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            res = await client.get(
                f"{FHIR_SERVER_URL}/Patient",
                params={"identifier": identifier},
                headers={"Accept": "application/fhir+json"},
            )
    except httpx.ConnectError:
        raise HTTPException(status_code=502, detail="無法連線至 FHIR Server")

    entries = res.json().get("entry", [])
    if not entries:
        raise HTTPException(status_code=404, detail="找不到此病患")

    resource = entries[0]["resource"]
    return PatientSearchResponse(fhir_id=resource["id"], patient=resource)


@app.get("/patients/{fhir_id}/appointments", response_model=AppointmentsResponse)
async def get_appointments(fhir_id: str):
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            res = await client.get(
                f"{FHIR_SERVER_URL}/Appointment",
                params={"patient": fhir_id},
                headers={"Accept": "application/fhir+json"},
            )
    except httpx.ConnectError:
        raise HTTPException(status_code=502, detail="無法連線至 FHIR Server")

    entries = res.json().get("entry", [])
    appointments = [
        AppointmentItem(
            id=e["resource"].get("id", ""),
            status=e["resource"].get("status", ""),
            start=e["resource"].get("start"),
            description=e["resource"].get("description", ""),
        )
        for e in entries
    ]
    return AppointmentsResponse(appointments=appointments)


@app.get("/health")
def health():
    return {"status": "ok"}


_frontend = Path(__file__).resolve().parents[2] / "frontend"

@app.get("/")
def index():
    return FileResponse(_frontend / "index.html")
