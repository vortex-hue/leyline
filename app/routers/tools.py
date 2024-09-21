# Import necessary modules
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from app.services.dns_service import resolve_ipv4
from app.database import get_db
from app.models import QueryLog
from app.schemas import QueryLogResponse
import ipaddress

#### Define the API router
router = APIRouter()

@router.post("/lookup", response_model=QueryLogResponse)
async def lookup_domain(domain: str, db: Session = Depends(get_db)):
    #### Resolve IPv4 addresses for the domain
    ipv4_addresses = resolve_ipv4(domain)
    if not ipv4_addresses:
        raise HTTPException(status_code=404, detail="IPv4 address not found")

    ##### Create a new log entry
    log = QueryLog(domain=domain, ipv4_address=ipv4_addresses[0])
    db.add(log)
    db.commit()
    db.refresh(log)
    return log

@router.get("/validate")
async def validate_ip(ip: str):
    ##### Validate if the input is a valid IPv4 address
    try:
        ipaddress.IPv4Address(ip)
        return {"is_valid": True}
    except ipaddress.AddressValueError:
        return {"is_valid": False}

@router.get("/history", response_model=list[QueryLogResponse])
async def get_history(db: Session = Depends(get_db)):
    ##### Retrieve the latest 20 saved queries
    logs = db.query(QueryLog).order_by(QueryLog.timestamp.desc()).limit(20).all()
    return logs
