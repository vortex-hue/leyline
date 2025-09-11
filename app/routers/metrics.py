from fastapi import APIRouter, Depends
from fastapi_limiter.depends import RateLimiter
from prometheus_client import Counter, Summary, generate_latest, CONTENT_TYPE_LATEST, Gauge, Histogram
from starlette.responses import Response
from app.security import check_rate_limit_dependency, require_scope, APIKeyData

router = APIRouter()

# Global metrics definitions
if 'REQUEST_COUNT' not in globals():
    REQUEST_COUNT = Counter("request_count", "Total number of requests", ["method", "endpoint", "http_status"])
    REQUEST_LATENCY = Summary("request_latency_seconds", "Request latency in seconds", ["method", "endpoint"])
    ACTIVE_CONNECTIONS = Gauge("active_connections", "Number of active connections")
    DNS_QUERIES_TOTAL = Counter("dns_queries_total", "Total DNS queries", ["domain", "status"])
    DNS_QUERY_DURATION = Histogram("dns_query_duration_seconds", "DNS query duration", ["domain"])
    API_KEY_USAGE = Counter("api_key_usage_total", "API key usage", ["user_id", "endpoint"])

@router.get("/metrics", dependencies=[Depends(check_rate_limit_dependency), Depends(require_scope("metrics:read"))])
async def get_metrics(current_user: APIKeyData = Depends(check_rate_limit_dependency)):
    """Prometheus metrics endpoint - requires authentication."""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
