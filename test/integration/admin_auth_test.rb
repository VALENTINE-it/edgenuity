require "test_helper"

class AdminAuthTest < ActionDispatch::IntegrationTest
  setup do
    RateLimiter.reset!
    @admin = Admin.find_by(username: "test_admin") || Admin.create!(
      username: "test_admin",
      email: "test_admin@example.com",
      password: "CorrectPassword123!",
      password_confirmation: "CorrectPassword123!",
      role: "admin"
    )
  end

  test "unauthorized requests to /api/admin/dashboard are rejected with 401" do
    get "/api/admin/dashboard"
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_equal "UNAUTHORIZED", json["error"]["code"]
  end

  test "admin login with correct credentials succeeds and allows dashboard access" do
    post "/api/admin/login", params: {
      username: "test_admin",
      password: "CorrectPassword123!"
    }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert_equal "test_admin", json["admin"]["username"]

    # Now access protected dashboard
    get "/api/admin/dashboard"
    assert_response :success
    dash_json = JSON.parse(response.body)
    assert_equal true, dash_json["success"]
    assert_equal "test_admin", dash_json["current_admin"]["username"]
    assert dash_json["summary"].key?("total_mentors")

    # Logout
    post "/api/admin/logout"
    assert_response :success

    # Access is once again blocked
    get "/api/admin/dashboard"
    assert_response :unauthorized
  end

  test "admin login with incorrect password returns 401" do
    post "/api/admin/login", params: {
      username: "test_admin",
      password: "WrongPassword!"
    }
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_equal "INVALID_CREDENTIALS", json["error"]["code"]
  end

  test "admin can create, update, and delete mentors" do
    # Authenticate
    post "/api/admin/login", params: {
      username: "test_admin",
      password: "CorrectPassword123!"
    }
    assert_response :success

    # Create mentor
    assert_difference("Mentor.count", 1) do
      post "/api/admin/mentors", params: {
        name: "Professor Turing",
        role: "Theoretical Computer Science",
        rating: 5.0,
        tags: "Algorithms, Cryptography"
      }
    end
    assert_response :created
    created_mentor = Mentor.find_by(name: "Professor Turing")
    assert_not_nil created_mentor

    # Update mentor
    put "/api/admin/mentors/#{created_mentor.id}", params: {
      role: "Senior Chair in Computer Science"
    }
    assert_response :success
    assert_equal "Senior Chair in Computer Science", created_mentor.reload.role

    # Delete mentor
    assert_difference("Mentor.count", -1) do
      delete "/api/admin/mentors/#{created_mentor.id}"
    end
    assert_response :success
  end
end
