# Edgenuity — Student-Mentor Learning Platform

A modern, responsive Student-Mentor Learning Platform built with **Roda** mounted inside **Ruby on Rails 7.2**, backed by **SQLite3 (WAL Mode)** and **Puma**.

---

## Architecture & Stack

- **Framework**: [Ruby on Rails 7.2](https://rubyonrails.org/) hosting ActiveRecord, SQLite3 database in WAL mode, Puma web server, and middleware.
- **Routing Engine**: [Roda 3.109](https://roda.jeremyevans.net/) mounted in `config/routes.rb` via `mount StudyPalApp.app => "/"`, providing high-performance tree routing, view rendering, and session handling.
- **Authentication & Security**: Bcrypt-hashed password credentials, session rotation upon authentication, secure HTTP-only cookies (`SameSite=Lax`, `HttpOnly=true`), and an in-memory token bucket rate limiter (`RateLimiter`).
- **Privacy & Cookie Consent**: Interactive cookie consent banner with granular data preference controls (Essential, Functional, Analytics, Personalization) persisted in the database and tied to visitor tokens and user accounts.
- **Styling**: Complete custom Edgenuity design system with Google Fonts (`DM Sans`, `Manrope`), responsive layouts for desktop, tablet, and mobile, and Tailwind CSS.
- **Database Models**: SQLite3 with `User`, `Mentor`, `MentoringSession`, `Admin`, `ContactMessage`, and `CookiePreference` ActiveRecord models.
- **Testing**: Comprehensive Minitest test suite covering unit models, authentication, cookie consent, rate limiting, security headers, health probes, and student booking workflows.

Detailed documentation:
- [ARCHITECTURE.md](ARCHITECTURE.md) — System architecture, concurrency, and topology.
- [SECURITY.md](SECURITY.md) — Security policies, threat mitigation, and rate limits.
- [DECISIONS.md](DECISIONS.md) — Architectural decision records (ADRs).
- [TASKS.md](TASKS.md) — Completed tasks and implementation roadmap.

---

## Key Features

1. **User Accounts & Authentication**:
   - Secure student registration and login with bcrypt password hashing.
   - Dual-tab authentication modal on the landing page with client-side and server-side validation.
   - Session fixation protection with session rotation on login and signup.
   - Protected student dashboard (`/dashboard`) with automatic login prompts for unauthenticated visitors.

2. **Cookie Consent & Data Preferences**:
   - Interactive consent banner allowing visitors to **Accept All**, **Decline Optional**, or **Customize Preferences**.
   - Granular privacy modal enabling users to toggle functional, analytical, and personalized data settings.
   - Persistent preferences stored in SQLite (`cookie_preferences`) linked to anonymous visitor tokens and authenticated student profiles.

3. **Student Dashboard & Mentoring Booking**:
   - Personalized student welcome banner displaying live account data.
   - Real-time booking flow connecting students to verified mentors with instant database persistence.
   - Data isolation ensuring students only view their own confirmed and upcoming mentoring sessions.

---

## API Endpoints

### Public & System Routes
- `GET /health/live` — Liveness probe (HTTP 200).
- `GET /health/ready` — Database readiness probe (HTTP 200 / 503).
- `GET /api/metrics` — Telemetry & connection pool stats.
- `GET /api/mentors` — Returns verified mentors in JSON format.
- `GET /api/mentors/:id` — Returns single mentor.
- `GET /api/sessions` — Returns mentoring sessions.
- `POST /api/contact` — Secure contact submission with spam protection.

### Cookie Consent & Privacy API
- `GET /api/cookie-consent` — Returns current visitor or authenticated user privacy settings.
- `POST /api/cookie-consent` — Saves consent choice (`accepted`, `denied`, or `custom` with granular toggles).

### Student Authentication API
- `POST /api/auth/signup` — Register student account via JSON payload.
- `POST /api/auth/login` — Authenticate student and establish session.
- `GET /api/auth/me` — Retrieve authenticated user profile.
- `POST /api/auth/logout` — Invalidate user session.

### Admin Routes (Protected)
- `POST /api/admin/login` — Authenticate admin (throttled).
- `POST /api/admin/logout` — Terminate admin session.
- `GET /api/admin/dashboard` — Platform overview & metrics.
- `GET /api/admin/mentors` — Manage mentors (CRUD).
- `GET /api/admin/sessions` — View and cancel mentoring sessions.
- `GET /api/admin/messages` — Review contact messages.

---

## Getting Started

### 1. Requirements
- Ruby `>= 3.1.0`
- Bundler & SQLite3

### 2. Setup
```bash
# Install dependencies
bundle install

# Run database migrations and seed data
bin/rails db:migrate
bin/rails db:seed
```

### 3. Administrator CLI Provisioning
```bash
# Create an admin account
bin/rails "admin:create[admin,admin@edgenuity.local,AdminSecurePass123!]"

# List existing admins
bin/rails admin:list

# Reset admin password
bin/rails "admin:reset_password[admin,NewSecurePassword456!]"
```

### 4. Database Backups & Maintenance
```bash
# Perform safe online backup (VACUUM INTO)
bin/rails db:backup

# Check SQLite database integrity
bin/rails db:integrity

# Run all scheduled maintenance tasks
bin/rails maintenance:run_all
```

### 5. Start the Server
```bash
# Development server with Tailwind CSS watcher
bin/dev

# Or standard Rails Puma server
bin/rails server -p 3000
```
Open [http://localhost:3000](http://localhost:3000) for the landing page or [http://localhost:3000/dashboard](http://localhost:3000/dashboard) for the student dashboard.

### 6. Run Tests
```bash
bin/rails test
```
