from fastapi import APIRouter, Depends
from fastapi_limiter.depends import RateLimiter
from prometheus_client import Counter, Summary, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response

router = APIRouter()

if 'REQUEST_COUNT' not in globals():
    REQUEST_COUNT = Counter("request_count", "Total number of requests", ["method", "endpoint", "http_status"])
    REQUEST_LATENCY = Summary("request_latency_seconds", "Request latency in seconds", ["method", "endpoint"])


@router.get("/metrics")
async def get_metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
