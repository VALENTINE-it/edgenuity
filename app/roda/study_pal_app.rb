require "roda"
require_relative "../helpers/study_pal_helper"

class StudyPalApp < Roda
  include StudyPalHelper

  plugin :render, views: Rails.root.join("app/views/study_pal"), layout: "./layout"
  plugin :all_verbs
  plugin :head
  plugin :json

  route do |r|
    # Flash notice
    @flash_notice = r.session["flash_notice"]
    r.session.delete("flash_notice")

    # Root route: Landing page (or redirect to dashboard if logged in)
    r.root do
      if r.session["user_logged_in"]
        r.redirect "/dashboard"
      else
        @mentors = Mentor.all
        view "index"
      end
    end

    # Student Dashboard route
    r.on "dashboard" do
      @mentors = Mentor.all
      @upcoming_session = MentoringSession.where(student_name: "Maya").order(session_date: :asc).first || MentoringSession.first
      view "dashboard"
    end

    # Mentors discovery route
    r.on "mentors" do
      r.is do
        @mentors = Mentor.all
        view "index"
      end

      r.is Integer do |mentor_id|
        @mentor = Mentor.find_by(id: mentor_id)
        if @mentor
          { id: @mentor.id, name: @mentor.name, role: @mentor.role, rating: @mentor.rating }
        else
          r.response.status = 404
          { error: "Mentor not found" }
        end
      end
    end

    # Bookings action
    r.post "bookings" do
      mentor = Mentor.find_by(id: r.params["mentor_id"]) || Mentor.first
      time_slot = r.params["selected_time"] || "Fri, 2:00 PM"
      help_type = r.params["help_type"] || "Assignment review"

      session_date = Date.today + 3.days
      MentoringSession.create!(
        student_name: "Maya",
        mentor: mentor,
        subject: mentor.tags_array.first&.upcase || "LEARNING",
        topic: "#{help_type} with #{mentor.name}",
        session_date: session_date,
        start_time: time_slot.split(", ").last || "2:00 PM",
        end_time: "2:45 PM",
        status: "confirmed",
        help_type: help_type
      )

      r.session["flash_notice"] = "You're all set! Your session with #{mentor.name} is booked for #{time_slot}."
      r.redirect "/dashboard"
    end

    # Login action
    r.post "login" do
      r.session["user_logged_in"] = true
      r.session["user_name"] = "Maya"
      r.session["flash_notice"] = "Welcome back, Maya!"
      r.redirect "/dashboard"
    end

    # Logout action
    r.on "logout" do
      r.session.delete("user_logged_in")
      r.session.delete("user_name")
      r.session["flash_notice"] = "You have been logged out successfully."
      r.redirect "/"
    end

    # API endpoints
    r.on "api" do
      r.on "mentors" do
        r.is do
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
      end

      r.on "sessions" do
        r.is do
          MentoringSession.includes(:mentor).all.map do |s|
            {
              id: s.id,
              student_name: s.student_name,
              mentor_name: s.mentor.name,
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
    end
  end
end
