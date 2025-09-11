import os
import time
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import HTTPException, status, Depends, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
import aioredis
import json

# Security configuration
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-super-secret-jwt-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
API_KEY_HEADER = os.getenv("API_KEY_HEADER", "X-API-Key")

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# JWT Bearer token scheme
security = HTTPBearer()

class TokenData(BaseModel):
    username: Optional[str] = None
    scopes: list[str] = []

class APIKeyData(BaseModel):
    key: str
    user_id: str
    scopes: list[str] = []
    rate_limit: int = 100
    expires_at: Optional[datetime] = None

class SecurityManager:
    def __init__(self):
        self.redis_client = None
        self.api_keys = {
            "leyline-api-key-2024": APIKeyData(
                key="leyline-api-key-2024",
                user_id="leyline-client",
                scopes=["dns:read", "dns:write", "metrics:read"],
                rate_limit=100
            ),
            "admin-key-2024": APIKeyData(
                key="admin-key-2024",
                user_id="admin",
                scopes=["dns:read", "dns:write", "metrics:read", "admin:all"],
                rate_limit=1000
            )
        }

    async def get_redis(self):
        if not self.redis_client:
            redis_url = os.getenv("REDIS_URL", "redis://redis:6379")
            self.redis_client = aioredis.from_url(redis_url, encoding="utf8", decode_responses=True)
        return self.redis_client

    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        """Verify a password against its hash."""
        return pwd_context.verify(plain_password, hashed_password)

    def get_password_hash(self, password: str) -> str:
        """Hash a password."""
        return pwd_context.hash(password)

    def create_access_token(self, data: dict, expires_delta: Optional[timedelta] = None):
        """Create a JWT access token."""
        to_encode = data.copy()
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        
        to_encode.update({"exp": expire, "iat": datetime.utcnow()})
        encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
        return encoded_jwt

    def verify_token(self, token: str) -> TokenData:
        """Verify and decode a JWT token."""
        credentials_exception = HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            username: str = payload.get("sub")
            scopes: list = payload.get("scopes", [])
            if username is None:
                raise credentials_exception
            token_data = TokenData(username=username, scopes=scopes)
        except JWTError:
            raise credentials_exception
        return token_data

    async def verify_api_key(self, api_key: str) -> APIKeyData:
        """Verify an API key and return its data."""
        if api_key not in self.api_keys:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid API key"
            )
        
        key_data = self.api_keys[api_key]
        
        # Check if key has expired
        if key_data.expires_at and datetime.utcnow() > key_data.expires_at:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="API key has expired"
            )
        
        return key_data

    async def check_rate_limit(self, api_key: str, endpoint: str) -> bool:
        """Check if the API key has exceeded its rate limit."""
        redis = await self.get_redis()
        current_time = int(time.time())
        minute_key = f"rate_limit:{api_key}:{endpoint}:{current_time // 60}"
        hour_key = f"rate_limit:{api_key}:{endpoint}:{current_time // 3600}"
        
        # Get current counts
        minute_count = await redis.get(minute_key) or 0
        hour_count = await redis.get(hour_key) or 0
        
        # Get rate limits for this key
        key_data = await self.verify_api_key(api_key)
        minute_limit = min(key_data.rate_limit, 60)  # Max 60 per minute
        hour_limit = key_data.rate_limit
        
        if int(minute_count) >= minute_limit or int(hour_count) >= hour_limit:
            return False
        
        # Increment counters
        pipe = redis.pipeline()
        pipe.incr(minute_key)
        pipe.expire(minute_key, 60)
        pipe.incr(hour_key)
        pipe.expire(hour_key, 3600)
        await pipe.execute()
        
        return True

    async def log_security_event(self, event_type: str, details: Dict[str, Any]):
        """Log security events for monitoring."""
        redis = await self.get_redis()
        event = {
            "timestamp": datetime.utcnow().isoformat(),
            "type": event_type,
            "details": details
        }
        await redis.lpush("security_events", json.dumps(event))
        await redis.ltrim("security_events", 0, 999)  # Keep last 1000 events

# Global security manager instance
security_manager = SecurityManager()

# Dependency functions
async def get_current_user_api_key(request: Request) -> APIKeyData:
    """Get current user from API key in header."""
    api_key = request.headers.get(API_KEY_HEADER)
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"API key required in {API_KEY_HEADER} header"
        )
    
    try:
        key_data = await security_manager.verify_api_key(api_key)
        return key_data
    except HTTPException as e:
        await security_manager.log_security_event("invalid_api_key", {
            "api_key": api_key[:8] + "...",
            "ip": request.client.host,
            "user_agent": request.headers.get("user-agent", "unknown")
        })
        raise e

async def get_current_user_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> TokenData:
    """Get current user from JWT token."""
    try:
        token_data = security_manager.verify_token(credentials.credentials)
        return token_data
    except HTTPException as e:
        await security_manager.log_security_event("invalid_token", {
            "token": credentials.credentials[:20] + "...",
            "error": str(e.detail)
        })
        raise e

async def check_rate_limit_dependency(request: Request, current_user: APIKeyData = Depends(get_current_user_api_key)):
    """Check rate limit for the current user."""
    endpoint = request.url.path
    if not await security_manager.check_rate_limit(current_user.key, endpoint):
        await security_manager.log_security_event("rate_limit_exceeded", {
            "api_key": current_user.key[:8] + "...",
            "endpoint": endpoint,
            "ip": request.client.host
        })
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rate limit exceeded"
        )
    return current_user

def require_scope(required_scope: str):
    """Decorator to require specific scope for endpoint access."""
    def scope_checker(current_user: APIKeyData = Depends(get_current_user_api_key)):
        if required_scope not in current_user.scopes:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Required scope: {required_scope}"
            )
        return current_user
    return scope_checker

# Health check endpoint doesn't require authentication
def no_auth_required():
    """Dependency for endpoints that don't require authentication."""
    return None
