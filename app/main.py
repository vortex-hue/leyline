from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import engine, Base
from app.config import settings
from app.routers import tools, health, metrics
import time  # Import the time module
import os    # Import the os module to use os.getenv

# Initialize the database tables
Base.metadata.create_all(bind=engine)

# Create the FastAPI app instance
app = FastAPI(title=settings.app_name, version=settings.version)

# Include the routers
app.include_router(tools.router, prefix="/v1/tools")
app.include_router(health.router)
app.include_router(metrics.router)

# Define the root endpoint
@app.get("/")
async def root():
    return {
        "version": settings.version,
        "date": int(time.time()),  
        "kubernetes": bool(os.getenv("KUBERNETES_SERVICE_HOST"))  
    }
