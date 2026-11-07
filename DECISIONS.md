# Architectural Decision Records (ADR) — Edgenuity Backend

## ADR 1: Retaining SQLite3 as the Primary Database
- **Status**: Accepted
- **Context**: The project was originally configured with SQLite. We considered whether to migrate to PostgreSQL.
- **Decision**: Retain SQLite3 configured in WAL (Write-Ahead Logging) mode with busy timeout (`5000ms`) and foreign keys enabled.
- **Rationale**:
  - Eliminates external database infrastructure dependencies.
  - WAL mode allows concurrent readers and writers on the local NVMe/SSD with microsecond query latency.
  - Zero-maintenance operational model with transactional backups via `VACUUM INTO`.
- **Trade-offs**: Single-node architecture; multiple distinct machines cannot write directly to the same SQLite database file over NFS. If horizontal scaling across multiple VPS instances is needed in the future, the application can migrate to PostgreSQL with minimal configuration change.

---

## ADR 2: Hybrid Roda Mounted Inside Ruby on Rails
- **Status**: Accepted
- **Context**: The application required high throughput routing while preserving the ecosystem benefits of Rails (ActiveRecord, ActiveJob, migrations, credentials, asset pipeline).
- **Decision**: Mount `Roda` at `/` in `config/routes.rb`.
- **Rationale**:
  - Roda's tree routing evaluates routes with minimal object allocation and latency.
  - Rails provides enterprise-grade database migrations, Puma process lifecycle, and security tooling.

---

## ADR 3: In-Memory Token Bucket Rate Limiter
- **Status**: Accepted
- **Context**: Endpoints required DDoS and brute-force mitigation without introducing Redis.
- **Decision**: Implement an in-memory thread-safe token bucket rate limiter in `app/services/rate_limiter.rb` with automatic stale-bucket pruning.
- **Rationale**:
  - Avoids adding Redis or extra network hops.
  - Thread-safe using `Monitor` synchronization.
  - Automatically purges inactive entries every 60 seconds to prevent unbounded memory growth.

---

## ADR 4: CLI-Based Administrator Provisioning
- **Status**: Accepted
- **Context**: Need to support administrative operations without exposing a public registration attack surface.
- **Decision**: Provide admin account provisioning via `bin/rails admin:create` and `bin/rails admin:reset_password`.
- **Rationale**:
  - Eliminates unauthenticated user registration vulnerabilities.
  - Enforces strong password requirements and bcrypt hashing.
