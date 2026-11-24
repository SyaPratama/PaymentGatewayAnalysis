# CipinCode AI Gateway - Technical Implementation Guide

**Version:** 1.0  
**Date:** 2026-10-29  
**Audience:** Developers implementing similar AI gateway systems

---

## 1. Architecture Pattern: AI Gateway as Unified API Layer

### Core Concept

```
Multiple AI Providers → Single Gateway → Unified API Interface
```

**Benefits:**
- Cost reduction (aggregate pricing power)
- Reliability (multi-provider failover)
- Simplicity (one API key, one format)
- Flexibility (easy provider switching)

---

## 2. Technology Stack Recommendation

Based on CipinCode's proven implementation:

| Component | CipinCode Uses | Alternatives |
|-----------|----------------|--------------|
| **Backend** | Laravel (PHP 8.4) | FastAPI (Python), Express (Node.js), Go Fiber |
| **Gateway** | 9Router | Custom proxy, Kong, Traefik |
| **Frontend** | React + Inertia.js | Next.js, Nuxt, SvelteKit |
| **Database** | MySQL/PostgreSQL (assumed) | PostgreSQL + Redis |
| **Cache** | Redis (assumed) | Redis, Memcached |
| **CDN** | hcdn (custom) | Cloudflare, Fastly |

### Minimal Tech Stack (Ponytail Approved)

For MVP (100-1000 users):
```
- Backend: FastAPI (Python) or Express (Node.js)
  → Fast development, good async support
  
- Gateway: Custom HTTP proxy with axios/httpx
  → No need for Kong/Traefik until 10k+ RPS
  
- Database: PostgreSQL
  → Single source of truth for users, quotas, keys
  
- Cache: Redis
  → Rate limiting, quota counters, session storage
  
- Frontend: Next.js
  → SSR for marketing, SPA for dashboard
```

**Avoid:**
- Microservices (monolith until 100k+ users)
- Kubernetes (VPS with Docker Compose sufficient)
- GraphQL (REST is simpler for AI APIs)
- Message queues (direct HTTP unless async processing needed)

---

## 3. Core Components Implementation

### 3.1 API Key Generation

```python
# Secure key generation
import secrets
import hashlib

def generate_api_key():
    """Generate cryptographically secure API key"""
    random_bytes = secrets.token_bytes(32)  # 256-bit entropy
    key = f"cipin_{secrets.token_urlsafe(32)}"
    return key

def hash_api_key(key: str) -> str:
    """Hash key for database storage (like password)"""
    import bcrypt
    return bcrypt.hashpw(key.encode(), bcrypt.gensalt()).decode()

def verify_api_key(key: str, hashed: str) -> bool:
    """Verify provided key against stored hash"""
    import bcrypt
    return bcrypt.checkpw(key.encode(), hashed.encode())
```

**Database Schema:**
```sql
CREATE TABLE api_keys (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    key_hash VARCHAR(60) NOT NULL,  -- bcrypt output
    key_prefix VARCHAR(20) NOT NULL,  -- "cipin_abc" for UI display
    created_at TIMESTAMP NOT NULL,
    last_used_at TIMESTAMP,
    revoked_at TIMESTAMP,
    INDEX idx_user (user_id),
    INDEX idx_prefix (key_prefix)
);
```

**Why hash keys?**
- If database leaked, attackers can't use keys
- Same principle as password storage
- Trade-off: Can't show full key to user after creation

---

### 3.2 Quota Enforcement (Race-Condition Safe)

```python
# PostgreSQL atomic decrement
import psycopg2

def consume_tokens(user_id: int, tokens_needed: int) -> bool:
    """
    Atomically check and decrement quota.
    Returns True if successful, False if insufficient quota.
    """
    query = """
        UPDATE user_quotas
        SET tokens_remaining = tokens_remaining - %s,
            updated_at = NOW()
        WHERE user_id = %s 
          AND tokens_remaining >= %s
          AND (expires_at IS NULL OR expires_at > NOW())
        RETURNING tokens_remaining
    """
    
    with conn.cursor() as cur:
        cur.execute(query, (tokens_needed, user_id, tokens_needed))
        result = cur.fetchone()
        
        if result is None:
            # Either insufficient quota or plan expired
            return False
        
        conn.commit()
        return True

# Usage in request handler
if not consume_tokens(user_id, estimated_tokens):
    return JSONResponse(
        status_code=429,
        content={"error": "Insufficient quota"}
    )
```

**Key Points:**
- Single UPDATE query (atomic at database level)
- Check and decrement in one operation
- No race condition even with 100 concurrent requests
- Returns updated balance for response header

---

### 3.3 Rate Limiting

```python
# Redis-based sliding window rate limiter
import redis
import time

redis_client = redis.Redis(host='localhost', port=6379, db=0)

def check_rate_limit(user_id: int, limit_rpm: int) -> tuple[bool, int]:
    """
    Sliding window rate limiter.
    Returns (allowed, remaining_requests)
    """
    key = f"ratelimit:{user_id}"
    now = time.time()
    window = 60  # 60 seconds
    
    # Remove old entries outside window
    redis_client.zremrangebyscore(key, 0, now - window)
    
    # Count requests in current window
    current = redis_client.zcard(key)
    
    if current >= limit_rpm:
        return False, 0
    
    # Add current request
    redis_client.zadd(key, {f"{now}:{secrets.token_hex(4)}": now})
    redis_client.expire(key, window)
    
    return True, limit_rpm - current - 1

# Usage
allowed, remaining = check_rate_limit(user_id, plan.rpm_limit)
if not allowed:
    return JSONResponse(
        status_code=429,
        content={"error": "Rate limit exceeded"},
        headers={"X-RateLimit-Reset": "60"}
    )
```

**Alternative (simpler but less accurate):**
```python
# Token bucket with Redis
def check_rate_limit_simple(user_id: int, limit_rpm: int) -> bool:
    key = f"ratelimit:{user_id}"
    current = redis_client.incr(key)
    
    if current == 1:
        redis_client.expire(key, 60)  # Reset every minute
    
    return current <= limit_rpm
```

**Ponytail Note:** Use simple version unless you need exact per-second precision.

---

### 3.4 Request Routing (9Router Pattern)

```python
# Simplified routing logic
from typing import List, Optional
import httpx
import asyncio

class ModelProvider:
    def __init__(self, name: str, base_url: str, api_key: str):
        self.name = name
        self.base_url = base_url
        self.api_key = api_key
        self.client = httpx.AsyncClient(timeout=30.0)
    
    async def call(self, model: str, messages: list) -> dict:
        """Call upstream provider API"""
        response = await self.client.post(
            f"{self.base_url}/chat/completions",
            json={"model": model, "messages": messages},
            headers={"Authorization": f"Bearer {self.api_key}"}
        )
        response.raise_for_status()
        return response.json()

class Router:
    def __init__(self, providers: dict[str, ModelProvider]):
        self.providers = providers
        self.model_map = {
            "cipin/deepseek-v4.1-flash": ("deepseek", "deepseek-chat"),
            "cipin/kimi-k2.8": ("moonshot", "moonshot-v1-32k"),
            "cipin/glm-5.3-flash": ("zhipu", "glm-4-flash"),
        }
    
    async def route(self, model: str, messages: list, strategy: str = "failover") -> dict:
        """Route request to appropriate provider"""
        if model not in self.model_map:
            raise ValueError(f"Unknown model: {model}")
        
        provider_name, upstream_model = self.model_map[model]
        
        if strategy == "failover":
            return await self._failover(provider_name, upstream_model, messages)
        elif strategy == "fastest":
            return await self._fastest(upstream_model, messages)
        else:
            raise ValueError(f"Unknown strategy: {strategy}")
    
    async def _failover(self, primary: str, model: str, messages: list) -> dict:
        """Try primary, fallback to backup on failure"""
        try:
            return await self.providers[primary].call(model, messages)
        except Exception as e:
            # Log error
            print(f"Primary provider {primary} failed: {e}")
            
            # Try backup
            for backup_name, backup in self.providers.items():
                if backup_name == primary:
                    continue
                try:
                    return await backup.call(model, messages)
                except:
                    continue
            
            raise Exception("All providers failed")
    
    async def _fastest(self, model: str, messages: list) -> dict:
        """Race all providers, return fastest"""
        tasks = [
            provider.call(model, messages) 
            for provider in self.providers.values()
        ]
        
        done, pending = await asyncio.wait(
            tasks, 
            return_when=asyncio.FIRST_COMPLETED
        )
        
        # Cancel slower requests
        for task in pending:
            task.cancel()
        
        return list(done)[0].result()

# Usage
router = Router({
    "deepseek": ModelProvider("deepseek", "https://api.deepseek.com", "sk-..."),
    "moonshot": ModelProvider("moonshot", "https://api.moonshot.cn", "sk-..."),
})

response = await router.route(
    model="cipin/deepseek-v4.1-flash",
    messages=[{"role": "user", "content": "Hello"}],
    strategy="failover"
)
```

**Ponytail Note:** Start with simple failover. "Fastest" strategy wastes 2x API quota.

---

### 3.5 Token Counting

```python
# Estimate tokens before calling upstream
import tiktoken

def count_tokens(messages: list, model: str = "gpt-4") -> int:
    """
    Estimate token count for quota deduction.
    Uses tiktoken (OpenAI's tokenizer).
    """
    encoding = tiktoken.encoding_for_model(model)
    
    num_tokens = 0
    for message in messages:
        # Format: <|im_start|>role\ncontent<|im_end|>
        num_tokens += 4  # Message overhead
        for key, value in message.items():
            num_tokens += len(encoding.encode(str(value)))
    
    num_tokens += 2  # Reply priming
    return num_tokens

# Usage
estimated_tokens = count_tokens(request.messages)

# Deduct upfront (pessimistic)
if not consume_tokens(user_id, estimated_tokens):
    return {"error": "Insufficient quota"}

# Call upstream
response = await router.route(...)

# Refund difference (if actual < estimated)
actual_tokens = response["usage"]["total_tokens"]
if actual_tokens < estimated_tokens:
    refund_tokens(user_id, estimated_tokens - actual_tokens)
```

**Alternative (simpler):**
```python
# Deduct after receiving response (optimistic)
response = await router.route(...)
actual_tokens = response["usage"]["total_tokens"]

if not consume_tokens(user_id, actual_tokens):
    # User exceeded quota mid-request
    # Log as debt, apply to next request
    log_quota_debt(user_id, actual_tokens)
```

**Ponytail Recommendation:** Use optimistic (simpler, no refunds). Quota debt is rare edge case.

---

## 4. Database Schema (Complete)

```sql
-- Users
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Plans
CREATE TABLE plans (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    price_idr INT NOT NULL,
    duration_days INT NOT NULL,
    token_quota BIGINT,  -- NULL = unlimited
    rpm_limit INT NOT NULL DEFAULT 30,
    active BOOLEAN DEFAULT true
);

-- User Subscriptions
CREATE TABLE subscriptions (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id),
    plan_id INT NOT NULL REFERENCES plans(id),
    purchased_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    tokens_remaining BIGINT,  -- NULL = unlimited
    active BOOLEAN DEFAULT true,
    INDEX idx_user_active (user_id, active, expires_at)
);

-- API Keys (hashed)
CREATE TABLE api_keys (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id),
    key_hash VARCHAR(60) NOT NULL,
    key_prefix VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    last_used_at TIMESTAMP,
    revoked_at TIMESTAMP,
    INDEX idx_user (user_id),
    UNIQUE idx_prefix (key_prefix)
);

-- Usage Logs (for analytics)
CREATE TABLE usage_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    model VARCHAR(100) NOT NULL,
    tokens_used INT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    INDEX idx_user_date (user_id, created_at),
    INDEX idx_created (created_at)
);

-- Partitioning for usage_logs (optional, if >1M rows/month)
CREATE TABLE usage_logs_2026_10 PARTITION OF usage_logs
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
```

**Indexes Rationale:**
- `idx_user_active`: Fast lookup for active subscription
- `idx_user_date`: Leaderboard queries
- `idx_created`: Cleanup old logs

---

## 5. API Endpoint Design

### 5.1 OpenAI-Compatible Endpoint

```python
# FastAPI example
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

app = FastAPI()

class ChatRequest(BaseModel):
    model: str
    messages: list[dict]
    temperature: float = 0.7
    max_tokens: int | None = None

@app.post("/v1/chat/completions")
async def chat_completions(
    request: ChatRequest,
    authorization: str = Header(...)
):
    # 1. Extract and validate API key
    if not authorization.startswith("Bearer "):
        raise HTTPException(401, "Invalid authorization header")
    
    api_key = authorization[7:]  # Remove "Bearer "
    user = await authenticate(api_key)
    if not user:
        raise HTTPException(401, "Invalid API key")
    
    # 2. Check rate limit
    allowed, remaining = check_rate_limit(user.id, user.rpm_limit)
    if not allowed:
        raise HTTPException(429, "Rate limit exceeded")
    
    # 3. Estimate tokens
    estimated = count_tokens(request.messages)
    
    # 4. Check quota
    if not consume_tokens(user.id, estimated):
        raise HTTPException(429, "Insufficient quota")
    
    # 5. Route to provider
    try:
        response = await router.route(
            model=request.model,
            messages=request.messages,
            strategy="failover"
        )
    except Exception as e:
        # Refund tokens on error
        refund_tokens(user.id, estimated)
        raise HTTPException(500, f"Provider error: {e}")
    
    # 6. Log usage
    actual_tokens = response["usage"]["total_tokens"]
    log_usage(user.id, request.model, actual_tokens)
    
    # 7. Return response
    return response
```

---

### 5.2 Response Format (OpenAI-Compatible)

```json
{
  "id": "chatcmpl-abc123",
  "object": "chat.completion",
  "created": 1730180623,
  "model": "cipin/deepseek-v4.1-flash",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Hello! How can I help you today?"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 12,
    "total_tokens": 22
  }
}
```

---

## 6. Deployment Architecture

### Minimal Setup (< 1000 users)

```
┌─────────────────────────────────────┐
│         Cloudflare (CDN)            │
│  - DDoS protection                  │
│  - SSL termination                  │
│  - Static asset caching             │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│    VPS (8GB RAM, 4 vCPU)            │
│  ┌───────────────────────────────┐  │
│  │  Docker Compose:              │  │
│  │  - FastAPI (2 workers)        │  │
│  │  - PostgreSQL 15              │  │
│  │  - Redis 7                    │  │
│  │  - Nginx (reverse proxy)      │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘

Cost: $40-80/month (Hetzner, DigitalOcean)
```

### Production Setup (10k+ users)

```
┌─────────────────────────────────────┐
│         Cloudflare (CDN)            │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│    Load Balancer (2x)               │
└──────────────┬──────────────────────┘
               │
       ┌───────┴───────┐
       ▼               ▼
┌─────────────┐ ┌─────────────┐
│  App 1      │ │  App 2      │
│  FastAPI    │ │  FastAPI    │
└─────────────┘ └─────────────┘
       │               │
       └───────┬───────┘
               ▼
┌─────────────────────────────────────┐
│    PostgreSQL (Primary + Replica)   │
└─────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│    Redis Cluster (3 nodes)          │
└─────────────────────────────────────┘

Cost: $200-500/month
```

---

## 7. Monitoring & Observability

### Key Metrics

```python
# Prometheus metrics (using prometheus_client)
from prometheus_client import Counter, Histogram, Gauge

# Request metrics
request_total = Counter(
    'api_requests_total',
    'Total API requests',
    ['model', 'status']
)

request_duration = Histogram(
    'api_request_duration_seconds',
    'Request duration',
    ['model', 'provider']
)

# Quota metrics
quota_remaining = Gauge(
    'user_quota_remaining',
    'User quota remaining',
    ['user_id']
)

# Provider metrics
provider_errors = Counter(
    'provider_errors_total',
    'Provider errors',
    ['provider', 'error_type']
)

# Usage in code
@request_duration.labels(model=request.model, provider="deepseek").time()
async def call_provider():
    ...
```

### Alerts

```yaml
# Prometheus alerting rules
groups:
  - name: api_gateway
    rules:
      - alert: HighErrorRate
        expr: rate(api_requests_total{status="error"}[5m]) > 0.05
        for: 5m
        annotations:
          summary: "Error rate > 5% for 5 minutes"
      
      - alert: ProviderDown
        expr: up{job="provider"} == 0
        for: 1m
        annotations:
          summary: "Provider {{ $labels.provider }} is down"
      
      - alert: HighLatency
        expr: histogram_quantile(0.95, api_request_duration_seconds) > 5
        for: 5m
        annotations:
          summary: "p95 latency > 5s"
```

---

## 8. Cost Analysis

### Revenue Per User (RPU)

**Assumptions:**
- Average plan: IDR 100,000/month
- Average usage: 20M tokens/month
- Upstream cost: $0.14/1M tokens (DeepSeek pricing)

```
Revenue: IDR 100,000 = ~$6.50 USD
Cost: 20M × $0.14 = $2.80 USD
Gross margin: $3.70 (57%)

Infrastructure: $0.50/user
Net margin: $3.20 (49%)
```

### Break-Even Analysis

```
Fixed costs: $200/month (server, domain, etc.)
Variable cost: $3.30/user (upstream + infra)
Revenue: $6.50/user

Break-even users: $200 / ($6.50 - $3.30) = 63 users
```

**Ponytail Note:** Simple pricing (unlimited) reduces support burden vs. complex per-token billing.

---

## 9. Common Pitfalls

### ❌ Don't: Store Upstream Keys in Code

```python
# BAD
DEEPSEEK_API_KEY = "sk-abc123..."
```

```python
# GOOD
import os
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY")
```

### ❌ Don't: Trust Client Token Counts

```python
# BAD
tokens_used = request.json.get("tokens")  # Client can lie!
consume_tokens(user_id, tokens_used)
```

```python
# GOOD
response = await call_provider(...)
tokens_used = response["usage"]["total_tokens"]
consume_tokens(user_id, tokens_used)
```

### ❌ Don't: Retry Failed Requests Without Idempotency

```python
# BAD
try:
    response = await provider.call(...)
except:
    response = await provider.call(...)  # Might double-charge!
```

```python
# GOOD
request_id = generate_idempotency_key()
response = await provider.call(..., headers={"X-Idempotency-Key": request_id})
```

### ❌ Don't: Build Microservices Day 1

- Start monolith (FastAPI/Laravel)
- Split only when one service hits 10k+ RPS
- Complexity costs more than vertical scaling until 100k users

---

## 10. Scaling Checklist

**0-100 users:**
- ✅ Single VPS
- ✅ PostgreSQL + Redis on same machine
- ✅ Manual deployments

**100-1,000 users:**
- ✅ Separate database server
- ✅ Redis cluster (3 nodes)
- ✅ Automated deployments (GitHub Actions)

**1,000-10,000 users:**
- ✅ Load balancer + 2 app servers
- ✅ PostgreSQL read replicas
- ✅ CDN for static assets
- ✅ Monitoring (Prometheus + Grafana)

**10,000+ users:**
- ✅ Auto-scaling app servers
- ✅ Multi-region deployment
- ✅ Database sharding (by user_id)
- ✅ Dedicated ops team

---

## 11. Testing Strategy

### Unit Tests

```python
# test_quota.py
def test_consume_tokens_success():
    user = create_test_user(quota=1000)
    result = consume_tokens(user.id, 500)
    assert result == True
    assert get_quota(user.id) == 500

def test_consume_tokens_insufficient():
    user = create_test_user(quota=100)
    result = consume_tokens(user.id, 500)
    assert result == False
    assert get_quota(user.id) == 100  # Unchanged

def test_consume_tokens_race_condition():
    user = create_test_user(quota=100)
    
    # 10 concurrent requests for 50 tokens each
    with ThreadPoolExecutor(max_workers=10) as executor:
        results = list(executor.map(
            lambda _: consume_tokens(user.id, 50),
            range(10)
        ))
    
    # Only 2 should succeed (100 / 50 = 2)
    assert sum(results) == 2
    assert get_quota(user.id) == 0
```

### Integration Tests

```python
# test_api.py
def test_chat_completion_success():
    api_key = create_test_key(quota=1000000)
    
    response = client.post(
        "/v1/chat/completions",
        headers={"Authorization": f"Bearer {api_key}"},
        json={
            "model": "cipin/deepseek-v4.1-flash",
            "messages": [{"role": "user", "content": "Hi"}]
        }
    )
    
    assert response.status_code == 200
    assert "choices" in response.json()

def test_chat_completion_quota_exceeded():
    api_key = create_test_key(quota=10)  # Very low
    
    response = client.post(
        "/v1/chat/completions",
        headers={"Authorization": f"Bearer {api_key}"},
        json={
            "model": "cipin/deepseek-v4.1-flash",
            "messages": [{"role": "user", "content": "Hi"}]
        }
    )
    
    assert response.status_code == 429
    assert "quota" in response.json()["error"].lower()
```

---

## 12. Conclusion

**Building an AI Gateway like CipinCode requires:**

1. **Secure API key management** (hash, don't store plaintext)
2. **Atomic quota enforcement** (prevent race conditions)
3. **Reliable routing** (failover > speed optimization)
4. **Simple architecture** (monolith > microservices until proven need)
5. **Good monitoring** (know when providers fail)

**Time to MVP:** 2-4 weeks (solo developer)  
**Tech debt accumulation:** Low (if following this guide)  
**Recommended stack:** FastAPI + PostgreSQL + Redis + Cloudflare

---

**Ponytail Verdict:** 8/10 implementability
- Straightforward architecture
- No exotic dependencies
- Clear scaling path
- Main risk: upstream provider terms changes

**Next Steps:**
1. Set up basic FastAPI project
2. Implement authentication + quota system
3. Add 1-2 providers (DeepSeek + OpenRouter as fallback)
4. Deploy on Hetzner VPS ($40/month)
5. Launch with "7-day unlimited" plan only
6. Add token plans after 100 users

---

**License:** MIT  
**Author:** Technical analysis of CipinCode.com  
**Last Updated:** 2026-10-29