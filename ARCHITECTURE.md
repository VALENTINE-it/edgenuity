# System Architecture — Edgenuity Backend

## 1. Executive Summary

Edgenuity is built as a high-performance modular monolith using **Ruby on Rails 7.2** hosting **Roda** as the mounted sub-router, **SQLite3** running in Write-Ahead Logging (WAL) mode, and **Puma** as the multi-threaded / clustered application web server.

The architecture is specifically engineered to balance developer productivity, minimal infrastructure dependencies, and high performance capable of handling concurrent read/write workloads.

---

## 2. Component Topology

```text
               Internet Traffic (Cloudflare Edge CDN / WAF)
                                     │
                                     ▼
                          Reverse Proxy (Nginx)
                   [HTTPS Termination, Gzip, SSL, Rate Limits]
                                     │
                                     ▼
                 Ruby on Rails 7.2 + Puma Web Server
          ┌──────────────────────────┴──────────────────────────┐
          ▼                                                     ▼
     Mounted Roda Engine                                ActiveRecord ORM
  - High-performance tree routing                    - Model validations
  - Error handler & Response JSON                     - Prepared SQL queries
  - Security headers & Request ID                     - Connection pooling
  - In-memory token bucket rate limiter               - Automatic cache triggers
          │                                                     │
          └──────────────────────────┬──────────────────────────┘
                                     │
                                     ▼
                           SQLite3 Database
                        (WAL Mode, Busy Timeout)
```

---

## 3. Layered Architecture

1. **Routing Layer (`Roda` mounted inside `Rails.application.routes`)**:
   - `config/routes.rb` delegates root paths to `StudyPalApp.app`.
   - Dynamic tree router provides sub-millisecond route resolution.
   - Centralized error handling catches all exceptions, prevents stack trace leakage, and emits uniform JSON errors correlated with `X-Request-Id`.

2. **Persistence Layer (`ActiveRecord` + `SQLite3`)**:
   - Configured with `PRAGMA journal_mode=WAL;` to eliminate read/write locking contention. Readers never block writers, and writers never block readers.
   - `PRAGMA busy_timeout=5000;` prevents `SQLite3::BusyException` under concurrent writes.
   - `PRAGMA foreign_keys=ON;` enforces relational integrity.
   - Connection pool dynamically sized using `RAILS_MAX_THREADS`.

3. **Security & Rate Limiting Layer (`RateLimiter`)**:
   - In-memory thread-safe token bucket rate limiter.
   - Configurable rate limits:
     - Public API: 100 req/min/IP
     - Admin login attempts: 5 attempts/min/IP
     - Contact & Bookings: 15 submissions/min/IP
   - Automatic memory pruning to prevent unbounded RAM growth.

4. **Authentication & Session Security Layer**:
   - `Admin` model protected by `has_secure_password` using bcrypt with cost factor 12.
   - Secure session cookies: `HttpOnly=true`, `SameSite=Lax`, `Secure=true` in production.
   - Automatic session rotation on login to eliminate session fixation attacks.

5. **Caching Layer (`Rails.cache`)**:
   - In-memory cache for public mentor collections.
   - Cache invalidation via `after_commit` model hooks.
   - HTTP caching headers (`ETag`, `Cache-Control: public, max-age=60`).

---

## 4. Scalability & Concurrency Readiness

- **Clustered Process Model**: Configurable Puma workers (`WEB_CONCURRENCY`) take advantage of multi-core CPU architectures while sharing SQLite WAL on the local filesystem.
- **Horizontal Scaling Path**: The modular codebase can be scaled horizontally behind a load balancer by switching the database adapter from SQLite to PostgreSQL and enabling Redis/SolidQueue for distributed sessions and background queues.
