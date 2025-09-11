from fastapi import APIRouter, Depends
from fastapi_limiter.depends import RateLimiter
from app.security import no_auth_required
import aioredis
import time

router = APIRouter()

@router.get("/health", dependencies=[Depends(RateLimiter(times=100, seconds=60))])
async def health_check():
    """Health check endpoint - no authentication required."""
    return {
        "status": "healthy",
        "timestamp": int(time.time()),
        "service": "LeyLine DNS Service"
    }
