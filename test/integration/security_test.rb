require "test_helper"

class SecurityTest < ActionDispatch::IntegrationTest
  setup do
    RateLimiter.reset!
  end

  test "response includes baseline security headers and unique request ID" do
    get "/"
    assert_response :success
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_equal "SAMEORIGIN", response.headers["X-Frame-Options"]
    assert response.headers["X-Request-Id"].present?
  end

  test "SQL injection in query parameters does not break or leak data" do
    get "/api/mentors/1%20OR%201=1"
    # Route expects Integer; non-integer or injection attempt results in 404
    assert_response :not_found
  end

  test "oversized request body is rejected with 413 Payload Too Large" do
    huge_body = "x" * (1_048_576 + 50)
    post "/api/contact", headers: { "CONTENT_LENGTH" => huge_body.bytesize.to_s }, params: { data: huge_body }
    assert_response :payload_too_large
  end
end
