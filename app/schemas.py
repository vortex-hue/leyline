from pydantic import BaseModel
from datetime import datetime

class QueryLogCreate(BaseModel):
    domain: str
    ipv4_address: str

class QueryLogResponse(BaseModel):
    domain: str
    ipv4_address: str
    timestamp: datetime

    class Config:
        orm_mode = True
