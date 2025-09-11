import os
import time
import logging
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Request, HTTPException, status
from fastapi_limiter import FastAPILimiter
from fastapi_limiter.depends import RateLimiter
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware

import aioredis
from app.config import settings
from app.database import Base, engine, SessionLocal
from app.routers import health, metrics, tools
from app.security import security_manager, check_rate_limit_dependency, no_auth_required

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Initialize the database tables
Base.metadata.create_all(bind=engine)

# Application lifespan management
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Starting LeyLine DNS Service...")
    redis_url = os.getenv("REDIS_URL", "redis://redis:6379")
    redis = aioredis.from_url(redis_url, encoding="utf8", decode_responses=True)
    await FastAPILimiter.init(redis)
    logger.info("Application startup complete")
    
    yield
    
    # Shutdown
    logger.info("Shutting down LeyLine DNS Service...")
    SessionLocal().close_all()
    engine.dispose()
    logger.info("Application shutdown complete")

# Create the FastAPI app instance
app = FastAPI(
    title=settings.app_name, 
    version=settings.version,
    lifespan=lifespan,
    docs_url="/docs" if settings.environment == "development" else None,
    redoc_url="/redoc" if settings.environment == "development" else None
)

# Add security middleware
app.add_middleware(
    TrustedHostMiddleware, 
    allowed_hosts=["*"] if settings.environment == "development" else ["localhost", "127.0.0.1"]
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.environment == "development" else ["https://yourdomain.com"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include the routers
app.include_router(tools.router, prefix="/v1/tools")
app.include_router(health.router)
app.include_router(metrics.router)


# Middleware to collect metrics
@app.middleware("http")
async def add_metrics(request: Request, call_next):
    method = request.method
    endpoint = request.url.path
    start_time = time.time()

    # Process the request and get the response
    response = await call_next(request)

    latency = time.time() - start_time
    status_code = response.status_code

    # Update Prometheus metrics
    if 'REQUEST_COUNT' in globals() and 'REQUEST_LATENCY' in globals():
        REQUEST_COUNT.labels(
            method=method, endpoint=endpoint, http_status=status_code
        ).inc()
        REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(latency)

    return response


# Root endpoint with enhanced security
@app.get("/", dependencies=[Depends(check_rate_limit_dependency)])
async def root():
    return {
        "service": "LeyLine DNS Service",
        "version": settings.version,
        "date": int(time.time()),
        "kubernetes": bool(os.getenv("KUBERNETES_SERVICE_HOST")),
        "environment": settings.environment,
        "status": "operational"
    }

# Readiness probe endpoint
@app.get("/ready")
async def readiness_check():
    """Readiness probe for Kubernetes."""
    try:
        # Check database connectivity
        db = SessionLocal()
        db.execute("SELECT 1")
        db.close()
        
        # Check Redis connectivity
        redis = await security_manager.get_redis()
        await redis.ping()
        
        return {"status": "ready", "checks": ["database", "redis"]}
    except Exception as e:
        logger.error(f"Readiness check failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Service not ready: {str(e)}"
        )

# Liveness probe endpoint
@app.get("/live")
async def liveness_check():
    """Liveness probe for Kubernetes."""
    return {"status": "alive", "timestamp": int(time.time())}
