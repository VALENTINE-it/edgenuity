# frozen_string_literal: true

require "roda"
require "securerandom"
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
      if r.session["user_logged_in"]
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
      @mentors = Rails.cache.fetch("public_mentors_collection", expires_in: 15.minutes) do
        Mentor.all.to_a
      end
      @upcoming_session = MentoringSession.where(student_name: "Maya").order(session_date: :asc).first || MentoringSession.first
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
        student_name: "Maya",
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

    # Student / Guest Login action
    r.post "login" do
      allowed, retry_after, _ = RateLimiter.check("student_login:#{@client_ip}", limit: 20, window: 60)
      unless allowed
        r.session["flash_notice"] = "Too many login attempts. Please wait #{retry_after} seconds."
        r.redirect "/"
      end

      # Student guest session
      r.session["user_logged_in"] = true
      r.session["user_name"] = "Maya"
      r.session["flash_notice"] = "Welcome back, Maya!"
      r.redirect "/dashboard"
    end

    # Student / Guest Logout action
    r.on "logout" do
      r.session.delete("user_logged_in")
      r.session.delete("user_name")
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
              mentors_count: Mentor.count,
              sessions_count: MentoringSession.count,
              unread_messages: ContactMessage.unread.count
            },
            memory: {
              tracked_rate_limit_keys: RateLimiter.stats[:tracked_keys]
            }
          }
        )
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
          json_error("VALIDATION_ERROR", msg.errors.full_messages.join(", "), status: 422)
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
              total_mentors: Mentor.count,
              total_sessions: MentoringSession.count,
              upcoming_sessions: MentoringSession.upcoming.count,
              unread_contact_messages: ContactMessage.unread.count,
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
                json_error("VALIDATION_ERROR", mentor.errors.full_messages.join(", "), status: 422)
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
                json_error("VALIDATION_ERROR", mentor.errors.full_messages.join(", "), status: 422)
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
              sessions = MentoringSession.includes(:mentor).order(session_date: :desc).limit(100).map do |s|
                {
                  id: s.id,
                  student_name: s.student_name,
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
