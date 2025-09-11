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
    redoc_url="/redoc" if settings.environment == "development" else None,
    openapi_tags=[
        {
            "name": "health",
            "description": "Health check endpoints (no authentication required)",
        },
        {
            "name": "dns",
            "description": "DNS lookup and validation operations (API key required)",
        },
        {
            "name": "metrics",
            "description": "Prometheus metrics endpoint (API key required)",
        },
    ]
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
app.include_router(tools.router, prefix="/v1/tools", tags=["dns"])
app.include_router(health.router, tags=["health"])
app.include_router(metrics.router, tags=["metrics"])

# Add API key authentication to OpenAPI schema
def get_openapi_schema():
    if app.openapi_schema:
        return app.openapi_schema
    
    from fastapi.openapi.utils import get_openapi
    
    openapi_schema = get_openapi(
        title=app.title,
        version=app.version,
        description="""
        # LeyLine DNS Service API
        
        A production-ready DNS lookup service with comprehensive security and monitoring.
        
        ## Authentication
        
        Most endpoints require an API key in the `X-API-Key` header. Health endpoints (`/health`, `/ready`, `/live`) do not require authentication.
        
        ### Available API Keys:
        - `leyline-api-key-2024` - Standard access (dns:read, dns:write, metrics:read)
        - `admin-key-2024` - Admin access (all permissions)
        - `test-key-2024` - Test access (limited permissions)
        
        ## Rate Limiting
        
        - Health endpoints: 100 requests/minute
        - API endpoints: 20 requests/minute
        - Metrics endpoint: 10 requests/minute
        
        ## Examples
        
        ```bash
        # Health check (no auth)
        curl http://localhost:8000/health
        
        # API call with authentication
        curl -H "X-API-Key: leyline-api-key-2024" http://localhost:8000/
        
        # DNS lookup
        curl -X POST -H "X-API-Key: leyline-api-key-2024" \\
          "http://localhost:8000/v1/tools/lookup?domain=example.com"
        ```
        """,
        routes=app.routes,
    )
    
    # Add security scheme
    openapi_schema["components"]["securitySchemes"] = {
        "ApiKeyAuth": {
            "type": "apiKey",
            "in": "header",
            "name": "X-API-Key",
            "description": "API key for authentication. Get your key from the Kong Admin API at http://localhost:8001/consumers"
        }
    }
    
    # Add security requirements to protected endpoints
    for path in openapi_schema["paths"]:
        if path not in ["/health", "/ready", "/live"]:
            for method in openapi_schema["paths"][path]:
                if method in ["get", "post", "put", "delete"]:
                    openapi_schema["paths"][path][method]["security"] = [{"ApiKeyAuth": []}]
    
    app.openapi_schema = openapi_schema
    return app.openapi_schema

app.openapi = get_openapi_schema


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
