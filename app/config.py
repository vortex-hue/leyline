import os
from pydantic import BaseSettings
from dotenv import load_dotenv

load_dotenv()

class Settings(BaseSettings):
    app_name: str = "Leyline Take Home |  DNS Service"
    version: str = "0.1.0"
    db_url: str = os.getenv("DATABASE_URL", "postgresql://user:password@localhost/dbname")
    environment: str = os.getenv("ENVIRONMENT", "local")
    prometheus_enabled: bool = os.getenv("PROMETHEUS_ENABLED", "true") == "true"

    class Config:
        env_file = ".env"

settings = Settings()
