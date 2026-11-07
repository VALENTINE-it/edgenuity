require "test_helper"

class StudyPalTest < ActionDispatch::IntegrationTest
  setup do
    RateLimiter.reset!
    @user = User.find_by(email: "maya.lin@school.edu") || User.create!(
      name: "Maya Lin",
      email: "maya.lin@school.edu",
      password: "Password123!",
      password_confirmation: "Password123!"
    )

    @mentor = Mentor.first || Mentor.create!(
      name: "Dr. Lena Ortiz",
      role: "Mathematics & Statistics",
      image: "https://images.unsplash.com/photo-1643297654473-049b273de9e6?auto=format&fit=crop&w=500&q=85",
      rating: 4.9,
      sessions_count: "240+ sessions",
      tags: "Calculus, Statistics",
      color: "#f4dcff"
    )
  end

  test "landing page renders successfully with Edgenuity branding and mentors" do
    get "/"
    assert_response :success
    assert_includes response.body, "edgenuity"
    assert_includes response.body, "imagine"
    assert_includes response.body, "Assignment help that finally"
    assert_includes response.body, "makes sense."
    assert_includes response.body, "Dr. Lena Ortiz"
    assert_includes response.body, "How it works"
  end

  test "unauthenticated visitor to dashboard is redirected to login" do
    get "/dashboard"
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Please log in or create an account"
  end

  test "dashboard renders successfully for authenticated student with recommendations" do
    post "/login", params: {
      email: "maya.lin@school.edu",
      password: "Password123!"
    }
    assert_response :redirect
    follow_redirect!
    assert_response :success

    assert_includes response.body, "Good morning, Maya!"
    assert_includes response.body, "Upcoming session"
    assert_includes response.body, "Mentors for you"
    assert_includes response.body, "Dr. Lena Ortiz"
  end

  test "booking a session persists record and redirects to dashboard with flash notice" do
    post "/login", params: {
      email: "maya.lin@school.edu",
      password: "Password123!"
    }
    assert_response :redirect

    assert_difference("MentoringSession.count", 1) do
      post "/bookings", params: {
        mentor_id: @mentor.id,
        selected_time: "Fri, 2:00 PM",
        help_type: "Assignment review"
      }
    end

    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_includes response.body, "You're all set!"
  end

  test "api mentors endpoint returns json collection" do
    get "/api/mentors"
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
    assert json.any? { |m| m["name"] == "Dr. Lena Ortiz" }
  end
end
