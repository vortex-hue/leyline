import os
import time

from fastapi import Depends, FastAPI, Request
from fastapi_limiter import FastAPILimiter
from fastapi_limiter.depends import RateLimiter

import aioredis
from app.config import settings
from app.database import Base, engine, SessionLocal
from app.routers import health, metrics, tools

# Initialize the database tables
Base.metadata.create_all(bind=engine)

# Create the FastAPI app instance
app = FastAPI(title=settings.app_name, version=settings.version)

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


# Root endpoint
@app.get("/", dependencies=[Depends(RateLimiter(times=5, seconds=60))])
async def root():
    return {
        "version": settings.version,
        "date": int(time.time()),
        "kubernetes": bool(os.getenv("KUBERNETES_SERVICE_HOST")),
    }


# Start rate limiter on startup
@app.on_event("startup")
async def startup():
    # Change 'localhost' to 'redis' to use the Docker Compose service name
    redis_url = os.getenv("REDIS_URL", "redis://redis:6379")
    redis = aioredis.from_url(redis_url, encoding="utf8", decode_responses=True)
    await FastAPILimiter.init(redis)


# Graceful shutdown handler
@app.on_event("shutdown")
async def shutdown_event():
    print("Shutting down the application gracefully...")
    # Close all active sessions
    SessionLocal().close_all()
    # Dispose of the engine to close all pooled connections
    engine.dispose()
