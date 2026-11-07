require "test_helper"

class RateLimitTest < ActionDispatch::IntegrationTest
  setup do
    RateLimiter.reset!
  end

  test "enforces rate limits and returns HTTP 429 when threshold exceeded" do
    # Trigger 5 login attempts
    5.times do
      post "/api/admin/login", params: { username: "fake_user", password: "wrong" }
    end

    # The 6th attempt should be blocked with 429 Too Many Requests
    post "/api/admin/login", params: { username: "fake_user", password: "wrong" }
    assert_response :too_many_requests
    assert response.headers["Retry-After"].present?

    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_equal "LOGIN_THROTTLED", json["error"]["code"]
  end
end
