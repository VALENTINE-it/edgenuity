require "test_helper"

class UserBookingTest < ActionDispatch::IntegrationTest
  setup do
    RateLimiter.reset!
    @mentor = Mentor.first || Mentor.create!(
      name: "Dr. Lena Ortiz",
      title: "Senior Research Fellow, MIT",
      rating: 4.98,
      reviews_count: 124,
      sessions_count: 340,
      badge: "Top Mentor",
      tags: "Mathematics,Calculus,Linear Algebra",
      avatar_url: "/assets/lena.png"
    )

    @user = User.create!(
      name: "Alex Parker",
      email: "alex@college.edu",
      password: "AlexPassword123!",
      password_confirmation: "AlexPassword123!"
    )
  end

  test "unauthenticated booking attempt redirects to login page" do
    assert_no_difference("MentoringSession.count") do
      post "/bookings", params: {
        mentor_id: @mentor.id,
        selected_time: "Thu, 3:00 PM",
        help_type: "Exam preparation"
      }
    end

    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "Please log in or create an account"
  end

  test "authenticated user can book a session and view it on their dashboard" do
    # Authenticate user
    post "/login", params: {
      email: "alex@college.edu",
      password: "AlexPassword123!"
    }
    assert_response :redirect

    assert_difference("MentoringSession.count", 1) do
      post "/bookings", params: {
        mentor_id: @mentor.id,
        selected_time: "Mon, 4:00 PM",
        help_type: "Final Project Review"
      }
    end

    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Your session with #{@mentor.name} is booked"

    # Verify session fields in database
    booking = MentoringSession.last
    assert_equal @user.id, booking.user_id
    assert_equal "Alex Parker", booking.student_name
    assert_equal @mentor.id, booking.mentor_id
    assert_equal "confirmed", booking.status
    assert_equal "Final Project Review", booking.help_type

    # Verify session is rendered on user's dashboard
    get "/dashboard"
    assert_response :success
    assert_includes response.body, "Final Project Review"
  end

  test "student dashboard only displays current user sessions" do
    # Create session for user 1
    session1 = MentoringSession.create!(
      user: @user,
      student_name: @user.name,
      mentor: @mentor,
      subject: "MATHEMATICS",
      topic: "Calculus III Review",
      session_date: Date.today + 2.days,
      start_time: "10:00 AM",
      end_time: "10:45 AM",
      status: "confirmed"
    )

    # Create user 2 with their own session
    user2 = User.create!(
      name: "Samira Khan",
      email: "samira@uni.edu",
      password: "SamiraPass123!",
      password_confirmation: "SamiraPass123!"
    )

    session2 = MentoringSession.create!(
      user: user2,
      student_name: user2.name,
      mentor: @mentor,
      subject: "PHYSICS",
      topic: "Quantum Mechanics",
      session_date: Date.today + 4.days,
      start_time: "2:00 PM",
      end_time: "2:45 PM",
      status: "confirmed"
    )

    # Login as User 2
    post "/login", params: {
      email: "samira@uni.edu",
      password: "SamiraPass123!"
    }
    assert_response :redirect

    get "/dashboard"
    assert_response :success
    assert_includes response.body, "Good morning, Samira!"
    assert_includes response.body, "Quantum Mechanics"
    assert_not_includes response.body, "Calculus III Review"
  end
end
