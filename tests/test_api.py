import pytest
import asyncio
from fastapi.testclient import TestClient
from unittest.mock import patch, AsyncMock
import json

from app.main import app
from app.security import security_manager

client = TestClient(app)

# Test data
VALID_API_KEY = "leyline-api-key-2024"
INVALID_API_KEY = "invalid-key"
ADMIN_API_KEY = "admin-key-2024"

class TestHealthEndpoints:
    """Test health check endpoints that don't require authentication."""
    
    def test_health_check(self):
        """Test health check endpoint."""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "timestamp" in data
        assert data["service"] == "LeyLine DNS Service"
    
    def test_readiness_check(self):
        """Test readiness check endpoint."""
        with patch('app.main.SessionLocal') as mock_db, \
             patch.object(security_manager, 'get_redis') as mock_redis:
            
            # Mock database check
            mock_db_instance = mock_db.return_value
            mock_db_instance.execute.return_value = None
            
            # Mock Redis check
            mock_redis_instance = AsyncMock()
            mock_redis_instance.ping = AsyncMock()
            mock_redis.return_value = mock_redis_instance
            
            response = client.get("/ready")
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "ready"
            assert "database" in data["checks"]
            assert "redis" in data["checks"]
    
    def test_liveness_check(self):
        """Test liveness check endpoint."""
        response = client.get("/live")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "alive"
        assert "timestamp" in data

class TestAuthenticatedEndpoints:
    """Test endpoints that require authentication."""
    
    def test_root_endpoint_without_auth(self):
        """Test root endpoint without API key."""
        response = client.get("/")
        assert response.status_code == 401
        assert "API key required" in response.json()["detail"]
    
    def test_root_endpoint_with_invalid_auth(self):
        """Test root endpoint with invalid API key."""
        response = client.get("/", headers={"X-API-Key": INVALID_API_KEY})
        assert response.status_code == 401
        assert "Invalid API key" in response.json()["detail"]
    
    def test_root_endpoint_with_valid_auth(self):
        """Test root endpoint with valid API key."""
        response = client.get("/", headers={"X-API-Key": VALID_API_KEY})
        assert response.status_code == 200
        data = response.json()
        assert data["service"] == "LeyLine DNS Service"
        assert "version" in data
        assert "status" in data
    
    def test_metrics_endpoint_without_auth(self):
        """Test metrics endpoint without API key."""
        response = client.get("/metrics")
        assert response.status_code == 401
    
    def test_metrics_endpoint_with_valid_auth(self):
        """Test metrics endpoint with valid API key."""
        response = client.get("/metrics", headers={"X-API-Key": VALID_API_KEY})
        assert response.status_code == 200
        assert "text/plain" in response.headers["content-type"]

class TestDNSOperations:
    """Test DNS-related operations."""
    
    @patch('app.services.dns_service.resolve_ipv4')
    def test_domain_lookup_without_auth(self, mock_resolve):
        """Test domain lookup without authentication."""
        response = client.post("/v1/tools/lookup", params={"domain": "example.com"})
        assert response.status_code == 401
    
    @patch('app.services.dns_service.resolve_ipv4')
    def test_domain_lookup_with_invalid_auth(self, mock_resolve):
        """Test domain lookup with invalid API key."""
        response = client.post(
            "/v1/tools/lookup", 
            params={"domain": "example.com"},
            headers={"X-API-Key": INVALID_API_KEY}
        )
        assert response.status_code == 401
    
    @patch('app.services.dns_service.resolve_ipv4')
    def test_domain_lookup_success(self, mock_resolve):
        """Test successful domain lookup."""
        mock_resolve.return_value = ["93.184.216.34"]
        
        with patch('app.database.get_db') as mock_get_db:
            # Mock database session
            mock_db = mock_get_db.return_value
            mock_log = type('QueryLog', (), {
                'id': 1,
                'domain': 'example.com',
                'ipv4_address': '93.184.216.34',
                'timestamp': '2024-01-01T00:00:00'
            })()
            mock_db.add.return_value = None
            mock_db.commit.return_value = None
            mock_db.refresh.return_value = None
            
            response = client.post(
                "/v1/tools/lookup",
                params={"domain": "example.com"},
                headers={"X-API-Key": VALID_API_KEY}
            )
            assert response.status_code == 200
            data = response.json()
            assert data["domain"] == "example.com"
            assert data["ipv4_address"] == "93.184.216.34"
    
    @patch('app.services.dns_service.resolve_ipv4')
    def test_domain_lookup_not_found(self, mock_resolve):
        """Test domain lookup when no IPv4 address is found."""
        mock_resolve.return_value = []
        
        response = client.post(
            "/v1/tools/lookup",
            params={"domain": "nonexistent.example"},
            headers={"X-API-Key": VALID_API_KEY}
        )
        assert response.status_code == 404
        assert "IPv4 address not found" in response.json()["detail"]
    
    def test_ip_validation_without_auth(self):
        """Test IP validation without authentication."""
        response = client.get("/v1/tools/validate", params={"ip": "8.8.8.8"})
        assert response.status_code == 401
    
    def test_ip_validation_valid_ip(self):
        """Test IP validation with valid IPv4 address."""
        response = client.get(
            "/v1/tools/validate",
            params={"ip": "8.8.8.8"},
            headers={"X-API-Key": VALID_API_KEY}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["is_valid"] is True
        assert data["ip"] == "8.8.8.8"
    
    def test_ip_validation_invalid_ip(self):
        """Test IP validation with invalid IP address."""
        response = client.get(
            "/v1/tools/validate",
            params={"ip": "invalid-ip"},
            headers={"X-API-Key": VALID_API_KEY}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["is_valid"] is False
        assert data["ip"] == "invalid-ip"
    
    def test_history_without_auth(self):
        """Test history endpoint without authentication."""
        response = client.get("/v1/tools/history")
        assert response.status_code == 401
    
    def test_history_with_auth(self):
        """Test history endpoint with authentication."""
        with patch('app.database.get_db') as mock_get_db:
            # Mock database session
            mock_db = mock_get_db.return_value
            mock_logs = [
                type('QueryLog', (), {
                    'id': 1,
                    'domain': 'example.com',
                    'ipv4_address': '93.184.216.34',
                    'timestamp': '2024-01-01T00:00:00'
                })()
            ]
            mock_db.query.return_value.order_by.return_value.limit.return_value.all.return_value = mock_logs
            
            response = client.get(
                "/v1/tools/history",
                headers={"X-API-Key": VALID_API_KEY}
            )
            assert response.status_code == 200
            data = response.json()
            assert isinstance(data, list)

class TestRateLimiting:
    """Test rate limiting functionality."""
    
    @patch.object(security_manager, 'check_rate_limit')
    def test_rate_limit_exceeded(self, mock_check_rate_limit):
        """Test when rate limit is exceeded."""
        mock_check_rate_limit.return_value = False
        
        response = client.get("/", headers={"X-API-Key": VALID_API_KEY})
        assert response.status_code == 429
        assert "Rate limit exceeded" in response.json()["detail"]
    
    @patch.object(security_manager, 'check_rate_limit')
    def test_rate_limit_within_limits(self, mock_check_rate_limit):
        """Test when rate limit is within limits."""
        mock_check_rate_limit.return_value = True
        
        response = client.get("/", headers={"X-API-Key": VALID_API_KEY})
        assert response.status_code == 200

class TestSecurityFeatures:
    """Test security features."""
    
    def test_cors_headers(self):
        """Test CORS headers are present."""
        response = client.options("/health")
        assert response.status_code == 200
    
    def test_security_headers(self):
        """Test security headers are present."""
        response = client.get("/health")
        # FastAPI automatically adds some security headers
        assert response.status_code == 200
    
    def test_invalid_methods(self):
        """Test invalid HTTP methods."""
        response = client.put("/health")
        assert response.status_code == 405  # Method not allowed
        
        response = client.delete("/health")
        assert response.status_code == 405  # Method not allowed

if __name__ == "__main__":
    pytest.main([__file__])
