from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .database import Base, SessionLocal, engine, get_db
from .models import HospitalRouting

app = FastAPI(title="FHIRpass Server", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await _seed()


async def _seed():
    async with SessionLocal() as db:
        result = await db.execute(select(HospitalRouting))
        if result.scalars().first() is not None:
            return

        db.add(HospitalRouting(
            fhir_id="LOGICA_DEMO_HOSPITAL",
            hospital_name="FHIRpass 雲端模擬醫院",
            fhir_base_url="https://sandbox.logicahealth.org/fhirpass_mvp/api/FHIR/R4",
            smart_well_known_url=(
                "https://sandbox.logicahealth.org/fhirpass_mvp/api/FHIR/R4"
                "/.well-known/smart-configuration"
            ),
            is_active=True,
        ))
        await db.commit()


# MARK: - Response Schemas

class HospitalOut(BaseModel):
    fhir_id: str
    hospital_name: str
    fhir_base_url: str
    is_active: bool

    model_config = {"from_attributes": True}


# MARK: - Routes

@app.get("/hospitals", response_model=list[HospitalOut])
async def list_hospitals(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(HospitalRouting).where(HospitalRouting.is_active == True)
    )
    return result.scalars().all()


@app.get("/hospitals/{fhir_id}", response_model=HospitalOut)
async def get_hospital(fhir_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(HospitalRouting).where(HospitalRouting.fhir_id == fhir_id)
    )
    hospital = result.scalars().first()
    if hospital is None:
        raise HTTPException(status_code=404, detail="Hospital not found")
    return hospital


@app.get("/health")
async def health():
    return {"status": "ok"}
