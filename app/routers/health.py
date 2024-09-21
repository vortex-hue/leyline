from fastapi import APIRouter, Depends
from fastapi_limiter.depends import RateLimiter
import aioredis

router = APIRouter()

@router.get("/health", dependencies=[Depends(RateLimiter(times=5, seconds=60))])
async def health_check():
    return {"status": "healthy"}
