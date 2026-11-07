# frozen_string_literal: true

require "roda"
require "securerandom"
require "json"
require_relative "../helpers/study_pal_helper"
require_relative "../services/rate_limiter"

class StudyPalApp < Roda
  include StudyPalHelper

  plugin :render, views: Rails.root.join("app/views/study_pal"), layout: "./layout"
  plugin :all_verbs
  plugin :head
  plugin :json
  plugin :error_handler

  MAX_BODY_BYTES = 1_048_576 # 1 MB body size restriction

  # Centralized Error Handling
  error do |e|
    req_id = @request_id || SecureRandom.uuid
    Rails.logger.error("[ERROR] [#{req_id}] #{e.class}: #{e.message}\n#{e.backtrace.first(8).join("\n")}")

    if request.path.start_with?("/api") || request.path.start_with?("/health")
      response.status = 500
      {
        success: false,
        error: {
          code: "INTERNAL_SERVER_ERROR",
          message: "An unexpected error occurred. Please contact support if the issue persists.",
          request_id: req_id
        }
      }
    else
      @title = "Error — Edgenuity"
      response.status = 500
      "<div style='font-family: sans-serif; text-align: center; padding: 60px;'><h2>Something went wrong</h2><p>Request ID: #{req_id}</p><a href='/'>Return to Home</a></div>"
    end
  end

  route do |r|
    # Request ID and Context Setup
    @request_id = r.env["action_dispatch.request_id"] || SecureRandom.uuid
    r.response["X-Request-Id"] = @request_id
    r.response["X-Content-Type-Options"] = "nosniff"
    r.response["X-Frame-Options"] = "SAMEORIGIN"

    # Client IP Resolution
    @client_ip = (r.env["action_dispatch.remote_ip"] || r.env["REMOTE_ADDR"] || "127.0.0.1").to_s

    # Request Body Size Limitation Check
    content_length = r.env["CONTENT_LENGTH"].to_i
    if content_length > MAX_BODY_BYTES
      r.response.status = 413
      r.halt(r.response.finish) if !r.path.start_with?("/api")
      return {
        success: false,
        error: {
          code: "PAYLOAD_TOO_LARGE",
          message: "Request payload exceeds maximum allowed size of 1MB",
          request_id: @request_id
        }
      }
    end

    # Visitor Token Resolution for Session & Privacy Consent
    @visitor_token = r.cookies["edgenuity_visitor_token"]
    if @visitor_token.blank?
      @visitor_token = SecureRandom.hex(16)
      r.response.set_cookie("edgenuity_visitor_token", {
        value: @visitor_token,
        path: "/",
        expires: 1.year.from_now,
        httponly: true,
        same_site: :lax
      })
    end

    # Authenticated User Resolution
    @current_user = nil
    if r.session["user_id"].present?
      @current_user = User.find_by(id: r.session["user_id"])
    end

    # Cookie Consent State Resolution
    consent_cookie = r.cookies["edgenuity_consent"]
    @cookie_consent = nil
    if consent_cookie.present?
      begin
        @cookie_consent = JSON.parse(consent_cookie)
      rescue StandardError
        @cookie_consent = nil
      end
    end

    if @cookie_consent.nil? && @current_user&.cookie_preference
      pref = @current_user.cookie_preference
      @cookie_consent = {
        "status" => pref.consent_status,
        "essential" => pref.essential,
        "functional" => pref.functional,
        "analytics" => pref.analytics,
        "personalization" => pref.personalization
      }
    end

    # Flash Notice Handling
    @flash_notice = r.session["flash_notice"]
    r.session.delete("flash_notice")

    # Helper methods for standard JSON responses
    def json_error(code, message, http_status: nil, status: nil)
      code_num = http_status || status || 400
      response.status = code_num
      {
        success: false,
        error: {
          code: code,
          message: message,
          request_id: @request_id
        }
      }
    end

    def json_success(data = nil, http_status: nil, **kwargs)
      status_code = http_status || 200
      response.status = status_code
      res = { success: true }
      res.merge!(data) if data.is_a?(Hash)
      res.merge!(kwargs) unless kwargs.empty?
      res
    end

    # Public Health Check Endpoints (Phase 2 & 9)
    r.on "health" do
      # Liveness probe
      r.is "live" do
        json_success(
          status: "alive",
          service: "edgenuity-backend",
          timestamp: Time.now.utc.iso8601
        )
      end

      # Readiness probe (verifies database connectivity)
      r.is "ready" do
        begin
          ActiveRecord::Base.connection_pool.with_connection do |conn|
            conn.execute("SELECT 1;")
          end
          json_success(
            status: "ready",
            database: "connected",
            timestamp: Time.now.utc.iso8601
          )
        rescue StandardError => e
          json_error("DATABASE_UNAVAILABLE", "Database readiness probe failed: #{e.message}", http_status: 503)
        end
      end
    end

    # Root route: Landing page (or redirect to dashboard if logged in)
    r.root do
      if @current_user
        r.redirect "/dashboard"
      else
        @mentors = Rails.cache.fetch("public_mentors_collection", expires_in: 15.minutes) do
          Mentor.all.to_a
        end
        view "index"
      end
    end

    # Student Dashboard route
    r.on "dashboard" do
      unless @current_user
        r.session["flash_notice"] = "Please log in or create an account to view your dashboard."
        r.redirect "/?login=true"
      end

      @mentors = Rails.cache.fetch("public_mentors_collection", expires_in: 15.minutes) do
        Mentor.all.to_a
      end
      @upcoming_session = @current_user.mentoring_sessions.upcoming.first
      @user_sessions = @current_user.mentoring_sessions.order(session_date: :asc).to_a
      view "dashboard"
    end

    # Mentors discovery route (HTML view)
    r.on "mentors" do
      r.is do
        @mentors = Rails.cache.fetch("public_mentors_collection", expires_in: 15.minutes) do
          Mentor.all.to_a
        end
        view "index"
      end
    end

    # Student Bookings action
    r.post "bookings" do
      unless @current_user
        r.session["flash_notice"] = "Please log in or create an account to book a mentoring session."
        r.redirect "/?login=true"
      end

      allowed, retry_after, _ = RateLimiter.check("booking:#{@client_ip}", limit: 15, window: 60)
      unless allowed
        r.session["flash_notice"] = "Too many booking attempts. Please wait #{retry_after} seconds."
        r.redirect "/dashboard"
      end

      mentor_id = r.params["mentor_id"]
      mentor = Mentor.find_by(id: mentor_id) || Mentor.first
      time_slot = r.params["selected_time"].to_s.strip
      time_slot = "Fri, 2:00 PM" if time_slot.empty?
      help_type = r.params["help_type"].to_s.strip
      help_type = "Assignment review" if help_type.empty?

      session_date = Date.today + 3.days
      MentoringSession.create!(
        user: @current_user,
        student_name: @current_user.name,
        mentor: mentor,
        subject: mentor&.tags_array&.first&.upcase || "LEARNING",
        topic: "#{help_type} with #{mentor&.name || 'Mentor'}",
        session_date: session_date,
        start_time: time_slot.split(", ").last || "2:00 PM",
        end_time: "2:45 PM",
        status: "confirmed",
        help_type: help_type
      )

      r.session["flash_notice"] = "You're all set! Your session with #{mentor&.name} is booked for #{time_slot}."
      r.redirect "/dashboard"
    end

    # User Registration (Sign up)
    r.post "signup" do
      allowed, retry_after, _ = RateLimiter.check("signup:#{@client_ip}", limit: 10, window: 60)
      unless allowed
        r.session["flash_notice"] = "Too many registration attempts. Please wait #{retry_after} seconds."
        r.redirect "/?signup=true"
      end

      name = r.params["name"].to_s.strip
      email = r.params["email"].to_s.strip.downcase
      password = r.params["password"].to_s
      password_conf = r.params["password_confirmation"].to_s.presence || password

      user = User.new(
        name: name,
        email: email,
        password: password,
        password_confirmation: password_conf
      )

      if user.save
        r.session.clear
        r.session["user_id"] = user.id
        user.update_columns(last_login_at: Time.now.utc, last_login_ip: @client_ip)

        # Associate any prior anonymous cookie consent
        if @visitor_token.present?
          CookiePreference.where(visitor_token: @visitor_token, user_id: nil).update_all(user_id: user.id)
        end

        r.session["flash_notice"] = "Welcome to Edgenuity, #{user.first_name}! Your account has been created."
        r.redirect "/dashboard"
      else
        r.session["flash_notice"] = user.errors.full_messages.join(". ")
        r.redirect "/?signup=true"
      end
    end

    # User Login
    r.post "login" do
      allowed, retry_after, _ = RateLimiter.check("login:#{@client_ip}", limit: 15, window: 60)
      unless allowed
        r.session["flash_notice"] = "Too many login attempts. Please wait #{retry_after} seconds."
        r.redirect "/?login=true"
      end

      email = r.params["email"].to_s.strip.downcase
      password = r.params["password"].to_s

      user = User.find_by(email: email)
      if user&.authenticate(password)
        r.session.clear
        r.session["user_id"] = user.id
        user.update_columns(last_login_at: Time.now.utc, last_login_ip: @client_ip)

        # Associate visitor cookie preferences with this user
        if @visitor_token.present?
          CookiePreference.where(visitor_token: @visitor_token, user_id: nil).update_all(user_id: user.id)
        end

        r.session["flash_notice"] = "Welcome back, #{user.first_name}!"
        r.redirect "/dashboard"
      else
        r.session["flash_notice"] = "Invalid email or password."
        r.redirect "/?login=true"
      end
    end

    # User Logout
    r.on "logout" do
      r.session.delete("user_id")
      r.session.clear
      r.session["flash_notice"] = "You have been logged out successfully."
      r.redirect "/"
    end

    # RESTful API Sub-routes
    r.on "api" do
      # Global API Rate Limiting (Phase 5)
      allowed, retry_after, remaining = RateLimiter.check("api:#{@client_ip}", limit: 100, window: 60)
      r.response["X-RateLimit-Limit"] = "100"
      r.response["X-RateLimit-Remaining"] = remaining.to_s
      unless allowed
        r.response["Retry-After"] = retry_after.to_s
        return json_error("RATE_LIMIT_EXCEEDED", "Rate limit exceeded. Try again in #{retry_after} seconds.", http_status: 429)
      end

      # Metrics Endpoint (Phase 9)
      r.get "metrics" do
        conn_pool = ActiveRecord::Base.connection_pool
        json_success(
          metrics: {
            uptime_seconds: (Time.now - Rails.application.config.boot_time rescue 0).to_i,
            database: {
              active_connections: conn_pool.stat[:busy],
              pool_size: conn_pool.stat[:size],
              waiting: conn_pool.stat[:waiting]
            },
            models: {
              users_count: User.count,
              mentors_count: Mentor.count,
              sessions_count: MentoringSession.count,
              unread_messages: ContactMessage.unread.count,
              cookie_preferences_count: CookiePreference.count
            },
            memory: {
              tracked_rate_limit_keys: RateLimiter.stats[:tracked_keys]
            }
          }
        )
      end

      # Cookie Consent & Data Preferences API
      r.on "cookie-consent" do
        r.get do
          pref = if @current_user&.cookie_preference
                   @current_user.cookie_preference
                 else
                   CookiePreference.find_by(visitor_token: @visitor_token)
                 end

          if pref
            json_success(
              status: pref.consent_status,
              essential: pref.essential,
              functional: pref.functional,
              analytics: pref.analytics,
              personalization: pref.personalization,
              consented_at: pref.consented_at
            )
          else
            json_success(
              status: "unprompted",
              essential: true,
              functional: false,
              analytics: false,
              personalization: false
            )
          end
        end

        r.post do
          status_choice = r.params["status"].to_s.strip
          status_choice = "custom" unless %w[accepted denied custom].include?(status_choice)

          is_accepted = (status_choice == "accepted")
          is_denied = (status_choice == "denied")

          functional = is_accepted ? true : (is_denied ? false : (r.params["functional"] == true || r.params["functional"] == "true" || r.params["functional"] == "1"))
          analytics = is_accepted ? true : (is_denied ? false : (r.params["analytics"] == true || r.params["analytics"] == "true" || r.params["analytics"] == "1"))
          personalization = is_accepted ? true : (is_denied ? false : (r.params["personalization"] == true || r.params["personalization"] == "true" || r.params["personalization"] == "1"))

          pref = CookiePreference.find_or_initialize_by(visitor_token: @visitor_token)
          pref.user = @current_user if @current_user
          pref.consent_status = status_choice
          pref.essential = true
          pref.functional = functional
          pref.analytics = analytics
          pref.personalization = personalization
          pref.ip_address = @client_ip
          pref.user_agent = r.env["HTTP_USER_AGENT"].to_s.truncate(255)
          pref.consented_at = Time.now.utc
          pref.save!

          cookie_payload = {
            status: status_choice,
            essential: true,
            functional: functional,
            analytics: analytics,
            personalization: personalization
          }

          r.response.set_cookie("edgenuity_consent", {
            value: cookie_payload.to_json,
            path: "/",
            expires: 1.year.from_now,
            same_site: :lax
          })

          json_success(
            message: "Cookie and data preferences saved successfully.",
            preferences: cookie_payload
          )
        end
      end

      # User Auth API Endpoints
      r.on "auth" do
        r.post "signup" do
          name = r.params["name"].to_s.strip
          email = r.params["email"].to_s.strip.downcase
          password = r.params["password"].to_s
          password_conf = r.params["password_confirmation"].to_s.presence || password

          user = User.new(
            name: name,
            email: email,
            password: password,
            password_confirmation: password_conf
          )

          if user.save
            r.session.clear
            r.session["user_id"] = user.id
            user.update_columns(last_login_at: Time.now.utc, last_login_ip: @client_ip)

            if @visitor_token.present?
              CookiePreference.where(visitor_token: @visitor_token, user_id: nil).update_all(user_id: user.id)
            end

            json_success(
              message: "Account created successfully",
              user: { id: user.id, name: user.name, email: user.email, role: user.role }
            )
          else
            json_error("VALIDATION_ERROR", user.errors.full_messages.join(", "), http_status: 422)
          end
        end

        r.post "login" do
          email = r.params["email"].to_s.strip.downcase
          password = r.params["password"].to_s

          user = User.find_by(email: email)
          if user&.authenticate(password)
            r.session.clear
            r.session["user_id"] = user.id
            user.update_columns(last_login_at: Time.now.utc, last_login_ip: @client_ip)

            if @visitor_token.present?
              CookiePreference.where(visitor_token: @visitor_token, user_id: nil).update_all(user_id: user.id)
            end

            json_success(
              message: "Login successful",
              user: { id: user.id, name: user.name, email: user.email, role: user.role }
            )
          else
            json_error("INVALID_CREDENTIALS", "Invalid email or password", http_status: 401)
          end
        end

        r.get "me" do
          if @current_user
            json_success(
              user: {
                id: @current_user.id,
                name: @current_user.name,
                email: @current_user.email,
                role: @current_user.role,
                grade_level: @current_user.grade_level
              }
            )
          else
            json_error("UNAUTHORIZED", "Not logged in", http_status: 401)
          end
        end

        r.post "logout" do
          r.session.delete("user_id")
          r.session.clear
          json_success(message: "Logged out successfully")
        end
      end

      # Contact Form Submissions (Phase 11)
      r.post "contact" do
        # Spam prevention via hidden honeypot field
        if r.params["website_url"].present?
          # Silently pretend success to bots
          return json_success(message: "Message received successfully.")
        end

        allowed_c, retry_after_c, _ = RateLimiter.check("contact:#{@client_ip}", limit: 10, window: 60)
        unless allowed_c
          r.response["Retry-After"] = retry_after_c.to_s
          return json_error("RATE_LIMIT_EXCEEDED", "Too many messages sent. Please retry in #{retry_after_c} seconds.", http_status: 429)
        end

        msg = ContactMessage.new(
          name: r.params["name"],
          email: r.params["email"],
          subject: r.params["subject"],
          message: r.params["message"],
          ip_address: @client_ip
        )

        if msg.save
          json_success(
            message: "Thank you for reaching out! Your message has been received.",
            message_id: msg.id
          )
        else
          json_error("VALIDATION_ERROR", msg.errors.full_messages.join(", "), http_status: 422)
        end
      end

      # Public Mentors Collection API (Phase 6 Caching)
      r.on "mentors" do
        r.is do
          r.response["Cache-Control"] = "public, max-age=60"
          mentors_json = Rails.cache.fetch("public_mentors_json", expires_in: 15.minutes) do
            Mentor.all.map do |m|
              {
                id: m.id,
                name: m.name,
                role: m.role,
                image: m.image,
                rating: m.rating.to_f,
                sessions_count: m.sessions_count,
                tags: m.tags_array,
                color: m.color
              }
            end
          end
          mentors_json
        end

        r.is Integer do |mentor_id|
          mentor = Mentor.find_by(id: mentor_id)
          if mentor
            {
              id: mentor.id,
              name: mentor.name,
              role: mentor.role,
              image: mentor.image,
              rating: mentor.rating.to_f,
              sessions_count: mentor.sessions_count,
              tags: mentor.tags_array,
              color: mentor.color
            }
          else
            json_error("NOT_FOUND", "Mentor with ID #{mentor_id} not found", http_status: 404)
          end
        end
      end

      # Public Sessions Collection API
      r.on "sessions" do
        r.is do
          MentoringSession.includes(:mentor).all.map do |s|
            {
              id: s.id,
              student_name: s.student_name,
              mentor_name: s.mentor&.name,
              subject: s.subject,
              topic: s.topic,
              session_date: s.session_date,
              start_time: s.start_time,
              end_time: s.end_time,
              status: s.status,
              help_type: s.help_type
            }
          end
        end
      end

      # Admin Authentication & Protected Endpoints (Phase 4)
      r.on "admin" do
        # Admin Login
        r.post "login" do
          allowed_l, retry_after_l, _ = RateLimiter.check("admin_login:#{@client_ip}", limit: 5, window: 60)
          unless allowed_l
            r.response["Retry-After"] = retry_after_l.to_s
            return json_error("LOGIN_THROTTLED", "Too many login attempts. Please wait #{retry_after_l} seconds.", http_status: 429)
          end

          username = r.params["username"].to_s.strip.downcase
          password = r.params["password"].to_s

          admin = Admin.find_by(username: username)
          if admin&.authenticate(password)
            # Session rotation to prevent session fixation attacks
            r.session.clear
            r.session["admin_id"] = admin.id
            r.session["admin_username"] = admin.username

            admin.update_columns(last_login_at: Time.now.utc, last_login_ip: @client_ip)

            json_success(
              message: "Admin login successful",
              admin: {
                id: admin.id,
                username: admin.username,
                email: admin.email,
                role: admin.role
              }
            )
          else
            json_error("INVALID_CREDENTIALS", "Invalid username or password", http_status: 401)
          end
        end

        # Admin Logout
        r.post "logout" do
          r.session.delete("admin_id")
          r.session.delete("admin_username")
          json_success(message: "Logged out successfully")
        end

        # Authorization Guard: Verify Authenticated Admin
        admin_id = r.session["admin_id"]
        current_admin = admin_id ? Admin.find_by(id: admin_id) : nil
        unless current_admin
          return json_error("UNAUTHORIZED", "Administrator authentication required", http_status: 401)
        end

        # Admin Dashboard Summary
        r.get "dashboard" do
          json_success(
            current_admin: {
              id: current_admin.id,
              username: current_admin.username,
              role: current_admin.role
            },
            summary: {
              total_users: User.count,
              total_mentors: Mentor.count,
              total_sessions: MentoringSession.count,
              upcoming_sessions: MentoringSession.upcoming.count,
              unread_contact_messages: ContactMessage.unread.count,
              total_cookie_preferences: CookiePreference.count,
              sqlite_journal_mode: ActiveRecord::Base.connection.execute("PRAGMA journal_mode;").first["journal_mode"]
            }
          )
        end

        # Admin Mentors Management (CRUD)
        r.on "mentors" do
          r.is do
            r.get do
              json_success(mentors: Mentor.order(created_at: :desc).all)
            end

            r.post do
              mentor = Mentor.new(
                name: r.params["name"],
                role: r.params["role"],
                image: r.params["image"],
                rating: r.params["rating"] || 5.0,
                sessions_count: r.params["sessions_count"] || "0 sessions",
                tags: r.params["tags"],
                color: r.params["color"] || "#f4dcff"
              )

              if mentor.save
                json_success({ message: "Mentor created successfully", mentor: mentor }, http_status: 201)
              else
                json_error("VALIDATION_ERROR", mentor.errors.full_messages.join(", "), http_status: 422)
              end
            end
          end

          r.is Integer do |mentor_id|
            mentor = Mentor.find_by(id: mentor_id)
            return json_error("NOT_FOUND", "Mentor #{mentor_id} not found", http_status: 404) unless mentor

            r.put do
              attrs = {
                name: r.params["name"],
                role: r.params["role"],
                image: r.params["image"],
                rating: r.params["rating"],
                sessions_count: r.params["sessions_count"],
                tags: r.params["tags"],
                color: r.params["color"]
              }.compact

              if mentor.update(attrs)
                json_success(message: "Mentor updated successfully", mentor: mentor)
              else
                json_error("VALIDATION_ERROR", mentor.errors.full_messages.join(", "), http_status: 422)
              end
            end

            r.delete do
              mentor.destroy
              json_success(message: "Mentor #{mentor_id} deleted successfully")
            end
          end
        end

        # Admin Mentoring Sessions
        r.on "sessions" do
          r.is do
            r.get do
              sessions = MentoringSession.includes(:mentor, :user).order(session_date: :desc).limit(100).map do |s|
                {
                  id: s.id,
                  student_name: s.student_name,
                  user_id: s.user_id,
                  mentor_name: s.mentor&.name,
                  subject: s.subject,
                  topic: s.topic,
                  session_date: s.session_date,
                  start_time: s.start_time,
                  status: s.status,
                  help_type: s.help_type
                }
              end
              json_success(sessions: sessions)
            end
          end

          r.is Integer do |session_id|
            session_rec = MentoringSession.find_by(id: session_id)
            return json_error("NOT_FOUND", "Session #{session_id} not found", http_status: 404) unless session_rec

            r.delete do
              session_rec.destroy
              json_success(message: "Session #{session_id} cancelled and removed")
            end
          end
        end

        # Admin Contact Messages
        r.on "messages" do
          r.is do
            r.get do
              messages = ContactMessage.recent.limit(100)
              json_success(messages: messages)
            end
          end

          r.is Integer do |message_id|
            msg = ContactMessage.find_by(id: message_id)
            return json_error("NOT_FOUND", "Message #{message_id} not found", http_status: 404) unless msg

            r.put "status" do
              new_status = r.params["status"].to_s.strip
              if %w[unread read replied archived].include?(new_status)
                msg.update_columns(status: new_status)
                json_success(message: "Message status updated to #{new_status}")
              else
                json_error("INVALID_STATUS", "Allowed statuses: unread, read, replied, archived", http_status: 422)
              end
            end
          end
        end
      end
    end
  end
end
