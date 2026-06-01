"""
QR Code 緊湊字串編解碼模組

格式：身分證|姓名|生日(YYYYMMDD)|性別(M/F)|電話
編碼：UTF-8 → zlib 壓縮 → Base64
"""

import base64
import zlib
from dataclasses import dataclass
from datetime import date, datetime


@dataclass
class PatientData:
    id_number: str   # 身分證字號
    name: str        # 姓名
    birthday: date   # 生日
    gender: str      # "male" | "female"
    phone: str       # 電話


def decode(payload: str) -> PatientData:
    """Base64 → zlib 解壓縮 → PatientData"""
    try:
        compact = zlib.decompress(base64.b64decode(payload)).decode("utf-8")
    except Exception as e:
        raise ValueError(f"解碼失敗: {e}")

    parts = compact.split("|")
    if len(parts) != 5:
        raise ValueError(f"格式錯誤：預期 5 個欄位，實際 {len(parts)} 個")

    id_number, name, birthday_str, gender_code, phone = parts

    try:
        birthday = datetime.strptime(birthday_str, "%Y%m%d").date()
    except ValueError:
        raise ValueError(f"生日格式錯誤：{birthday_str}，預期 YYYYMMDD")

    gender = "female" if gender_code == "F" else "male"

    return PatientData(
        id_number=id_number,
        name=name,
        birthday=birthday,
        gender=gender,
        phone=phone,
    )


def to_tw_core_patient(data: PatientData) -> dict:
    """PatientData → TW Core IG Patient JSON"""
    return {
        "resourceType": "Patient",
        "meta": {
            "profile": [
                "https://twcore.mohw.gov.tw/ig/twcore/StructureDefinition/Patient-twcore"
            ]
        },
        "identifier": [
            {
                "use": "official",
                "type": {
                    "coding": [
                        {
                            "system": "http://terminology.hl7.org/CodeSystem/v2-0203",
                            "code": "NNTWN",
                            "display": "National Person Identifier",
                        }
                    ]
                },
                "system": "http://moi.gov.tw",
                "value": data.id_number,
            }
        ],
        "name": [{"use": "official", "text": data.name}],
        "gender": data.gender,
        "birthDate": data.birthday.strftime("%Y-%m-%d"),
        "telecom": [
            {
                "system": "phone",
                "value": data.phone,
                "use": "mobile",
            }
        ],
    }
