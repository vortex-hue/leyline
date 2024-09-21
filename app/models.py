from sqlalchemy import Column, Integer, String, DateTime
from datetime import datetime
from .database import Base

class QueryLog(Base):
    __tablename__ = "query_logs"

    id = Column(Integer, primary_key=True, index=True)
    domain = Column(String, index=True)
    ipv4_address = Column(String)
    timestamp = Column(DateTime, default=datetime.utcnow)
