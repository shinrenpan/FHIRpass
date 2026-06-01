from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base


class HospitalRouting(Base):
    __tablename__ = "hospital_routing"

    fhir_id: Mapped[str] = mapped_column(String(50), primary_key=True)
    hospital_name: Mapped[str] = mapped_column(String(100), nullable=False)
    fhir_base_url: Mapped[str] = mapped_column(String(255), nullable=False)
    smart_well_known_url: Mapped[str | None] = mapped_column(String(255))
    auth_authorize_url: Mapped[str | None] = mapped_column(String(255))
    auth_token_url: Mapped[str | None] = mapped_column(String(255))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
