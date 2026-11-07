require "test_helper"

class UserAuthTest < ActionDispatch::IntegrationTest
  setup do
    RateLimiter.reset!
    @user = User.find_by(email: "registered@school.edu") || User.create!(
      name: "Jordan Lee",
      email: "registered@school.edu",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end

  test "unauthenticated user accessing /dashboard is redirected to root with login prompt" do
    get "/dashboard"
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Please log in or create an account"
  end

  test "user registration via /signup creates database record and establishes session" do
    assert_difference("User.count", 1) do
      post "/signup", params: {
        name: "Chloe Price",
        email: "chloe@arcadia.edu",
        password: "ChloeSecurePass99!",
        password_confirmation: "ChloeSecurePass99!"
      }
    end

    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Good morning, Chloe!"

    new_user = User.find_by(email: "chloe@arcadia.edu")
    assert_not_nil new_user
    assert_equal "Chloe Price", new_user.name
  end

  test "user registration with duplicate email fails and redirects with error" do
    assert_no_difference("User.count") do
      post "/signup", params: {
        name: "Jordan Duplicate",
        email: "registered@school.edu",
        password: "Password123!",
        password_confirmation: "Password123!"
      }
    end

    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "has already been taken"
  end

  test "user login with correct password succeeds and grants dashboard access" do
    post "/login", params: {
      email: "registered@school.edu",
      password: "Password123!"
    }

    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Good morning, Jordan!"

    # Verify logout
    get "/logout"
    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "logged out successfully"

    # Dashboard access is now revoked
    get "/dashboard"
    assert_response :redirect
  end

  test "user login with incorrect password fails" do
    post "/login", params: {
      email: "registered@school.edu",
      password: "WrongPassword99!"
    }

    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "Invalid email or password"
  end

  test "JSON auth API allows programmatic registration and authentication" do
    post "/api/auth/signup", params: {
      name: "API Tester",
      email: "api_tester@school.edu",
      password: "ApiPassword123!",
      password_confirmation: "ApiPassword123!"
    }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert_equal "api_tester@school.edu", json["user"]["email"]

    # Check /api/auth/me
    get "/api/auth/me"
    assert_response :success
    me_json = JSON.parse(response.body)
    assert_equal "API Tester", me_json["user"]["name"]

    # Logout via API
    post "/api/auth/logout"
    assert_response :success

    get "/api/auth/me"
    assert_response :unauthorized
  end
end
