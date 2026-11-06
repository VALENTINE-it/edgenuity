require "test_helper"

class StudyPalTest < ActionDispatch::IntegrationTest
  setup do
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

  test "landing page renders successfully with StudyPal branding and mentors" do
    get "/"
    assert_response :success
    assert_includes response.body, "Study"
    assert_includes response.body, "Pal"
    assert_includes response.body, "Assignment help that finally"
    assert_includes response.body, "makes sense."
    assert_includes response.body, "Dr. Lena Ortiz"
    assert_includes response.body, "How it works"
  end

  test "dashboard renders successfully with upcoming session and mentor recommendations" do
    get "/dashboard"
    assert_response :success
    assert_includes response.body, "Good morning, Maya!"
    assert_includes response.body, "Upcoming session"
    assert_includes response.body, "Mentors for you"
    assert_includes response.body, "Dr. Lena Ortiz"
  end

  test "booking a session persists record and redirects to dashboard with flash notice" do
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
