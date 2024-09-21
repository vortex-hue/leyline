import time
import os
from fastapi import FastAPI
from app.database import engine, Base, SessionLocal
from app.config import settings
from app.routers import tools, health, metrics

#### Initialize the database tables
Base.metadata.create_all(bind=engine)

#### Create the FastAPI app instance
app = FastAPI(title=settings.app_name, version=settings.version)

#### Include the routers
app.include_router(tools.router, prefix="/v1/tools")
app.include_router(health.router)
app.include_router(metrics.router)

#### Root endpoint
@app.get("/")
async def root():
    return {
        "version": settings.version,
        "date": int(time.time()),
        "kubernetes": bool(os.getenv("KUBERNETES_SERVICE_HOST"))
    }


#### Graceful shutdown handler
@app.on_event("shutdown")
async def shutdown_event():
    print("Shutting down the application gracefully...")
    #### Close all active sessions
    SessionLocal().close_all()
    #### Dispose of the engine to close all pooled connections
    engine.dispose()
