# Security Policy & Implementation — Edgenuity

## 1. Threat Mitigation & Defensive Architecture

Edgenuity implements multi-layered defense-in-depth protections across network, application, session, database, and process boundaries:

### 1.1 Authentication & Password Security
- **Bcrypt Password Hashing**: Passwords stored as salted, non-reversible hashes using bcrypt (`has_secure_password`).
- **No Public Admin Registration**: Admin accounts can only be provisioned via authorized CLI tasks (`bin/rails admin:create`) or authenticated administrators.
- **Session Fixation Prevention**: Session identifiers are immediately regenerated and rotated on authentication (`r.session.clear`).
- **Secure Cookie Flags**: Session cookies enforce `HttpOnly=true`, `SameSite=Lax`, and `Secure=true` in production environments.

### 1.2 Rate Limiting & Abuse Prevention
- Concurrency-safe token bucket limiter protects all sensitive and public endpoints.
- Brute-force throttling on login endpoints (max 5 attempts per minute per IP).
- Automated cleanup of stale limiter buckets to protect against memory exhaustion attacks.
- Returns HTTP `429 Too Many Requests` with RFC-compliant `Retry-After` headers.

### 1.3 Injection & Tampering Protections
- **SQL Injection**: All database operations use ActiveRecord parameterized statements or prepared queries. Raw string interpolation in queries is strictly prohibited.
- **Cross-Site Scripting (XSS)**: Automatic output escaping in ERB templates.
- **Spam & Automated Bots**: Contact form includes an invisible honeypot field (`website_url`). Bot submissions are silently dropped without consuming persistence resources.
- **Request Body Size Restrictions**: Payloads exceeding 1MB (`1,048,576 bytes`) are rejected immediately with HTTP `413 Payload Too Large`.

### 1.4 Baseline Security Headers
Every HTTP response carries the following hardened security headers:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: SAMEORIGIN`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: camera=(), microphone=(), geolocation=()`
- `Content-Security-Policy: default-src 'self' ...`

### 1.5 Database Safety & Backup Policy
- SQLite database files are stored in `storage/` outside the web root (`public/`).
- Scheduled online backups utilize transactional SQLite snapshots (`VACUUM INTO`) ensuring no read/write locking disruptions.
- Regular database integrity validation via `bin/rails db:integrity`.

---

## 2. Security Checklist for Production

- [ ] Set `RAILS_MASTER_KEY` or environment credentials.
- [ ] Configure HTTPS certificates (via Let's Encrypt / Certbot).
- [ ] Ensure `storage/` and `storage/backups/` have restricted file permissions (`chmod 700`).
- [ ] Protect edge using Cloudflare WAF and DDoS mitigation rules.
