# StudyPal — Student-Mentor Learning Platform

A modern, responsive Student-Mentor Learning Platform converted directly from the Figma Make design (`https://easing-jade-38325008.figma.site/`), built with **Roda** mounted inside the **Ruby on Rails** framework.

---

## Architecture & Stack

- **Framework**: [Ruby on Rails 7.2](https://rubyonrails.org/) hosting ActiveRecord, SQLite3 database, Puma web server, and middleware.
- **Routing Engine**: [Roda 3.109](https://roda.jeremyevans.net/) mounted in `config/routes.rb` via `mount StudyPalApp.app => "/"`, providing high-performance tree routing, view rendering, and session handling.
- **Styling**: Complete custom StudyPal design system with Google Fonts (`DM Sans`, `Manrope`), responsive layouts for desktop, tablet, and mobile, and Tailwind CSS.
- **Database**: SQLite3 with `Mentor` and `MentoringSession` ActiveRecord models.
- **Testing**: Minitest integration test suite covering landing page, student dashboard, booking persistence, and JSON API endpoints.

---

## Key Features

1. **Landing Page (`/`)**:
   - Hero section with live video support indicators, solved assignment badge, and social proof.
   - Subject categories: Mathematics, Computer Science, Physics, Chemistry, Writing.
   - 3-step learning workflow: *"From stuck to confident in three steps"*.
   - Verified Mentors showcase featuring Dr. Lena Ortiz, Noah Williams, and James Chen with ratings, session counts, and tags.
   - One-click login / guest student modal.

2. **Student Dashboard (`/dashboard`)**:
   - Personalized student welcome banner (*Good morning, Maya!*).
   - Upcoming session reminder with 1-click video room join and direct mentor messaging.
   - Weekly learning time progress tracker.
   - Mentor recommendation list with instant session booking.
   - Interactive booking modal with subject help selection and real-time date/time slot selection.

3. **API Endpoints**:
   - `GET /api/mentors` — Returns verified mentors in JSON format.
   - `GET /api/sessions` — Returns mentoring sessions in JSON format.

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

### 3. Start the Server
```bash
bin/rails server -p 3000
```
Open [http://localhost:3000](http://localhost:3000) to view the landing page, or [http://localhost:3000/dashboard](http://localhost:3000/dashboard) to explore the student dashboard.

### 4. Run Tests
```bash
bin/rails test test/integration/study_pal_test.rb
```
