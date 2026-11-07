require "test_helper"

class CookieConsentTest < ActionDispatch::IntegrationTest
  setup do
    RateLimiter.reset!
  end

  test "GET /api/cookie-consent returns unprompted when visitor has not recorded choice" do
    get "/api/cookie-consent"
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert_equal "unprompted", json["status"]
    assert_equal true, json["essential"]
    assert_equal false, json["functional"]
    assert_equal false, json["analytics"]
    assert_equal false, json["personalization"]
  end

  test "POST /api/cookie-consent with accepted status enables all preferences and sets cookie" do
    assert_difference("CookiePreference.count", 1) do
      post "/api/cookie-consent", params: { status: "accepted" }
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert_equal "accepted", json["preferences"]["status"]
    assert_equal true, json["preferences"]["functional"]
    assert_equal true, json["preferences"]["analytics"]
    assert_equal true, json["preferences"]["personalization"]

    # Verify database record
    pref = CookiePreference.last
    assert_equal "accepted", pref.consent_status
    assert_equal true, pref.essential
    assert_equal true, pref.functional
    assert_equal true, pref.analytics
    assert_equal true, pref.personalization
    assert_not_nil pref.consented_at

    # Subsequent GET returns the saved preferences
    get "/api/cookie-consent"
    assert_response :success
    get_json = JSON.parse(response.body)
    assert_equal "accepted", get_json["status"]
    assert_equal true, get_json["analytics"]
  end

  test "POST /api/cookie-consent with denied status denies non-essential cookies" do
    post "/api/cookie-consent", params: { status: "denied" }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "denied", json["preferences"]["status"]
    assert_equal true, json["preferences"]["essential"]
    assert_equal false, json["preferences"]["functional"]
    assert_equal false, json["preferences"]["analytics"]
    assert_equal false, json["preferences"]["personalization"]

    pref = CookiePreference.last
    assert_equal "denied", pref.consent_status
    assert_equal false, pref.functional
    assert_equal false, pref.analytics
  end

  test "POST /api/cookie-consent with custom status saves granular selections" do
    post "/api/cookie-consent", params: {
      status: "custom",
      functional: "true",
      analytics: "false",
      personalization: "true"
    }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "custom", json["preferences"]["status"]
    assert_equal true, json["preferences"]["essential"]
    assert_equal true, json["preferences"]["functional"]
    assert_equal false, json["preferences"]["analytics"]
    assert_equal true, json["preferences"]["personalization"]

    pref = CookiePreference.last
    assert_equal "custom", pref.consent_status
    assert_equal true, pref.functional
    assert_equal false, pref.analytics
    assert_equal true, pref.personalization
  end

  test "authenticated user's cookie preference links to user record" do
    user = User.create!(
      name: "Morgan Stark",
      email: "morgan@stark.edu",
      password: "Password123!",
      password_confirmation: "Password123!"
    )

    # Login user
    post "/login", params: {
      email: "morgan@stark.edu",
      password: "Password123!"
    }
    assert_response :redirect

    # Submit consent preference
    post "/api/cookie-consent", params: { status: "accepted" }
    assert_response :success

    pref = CookiePreference.find_by(user_id: user.id)
    assert_not_nil pref
    assert_equal "accepted", pref.consent_status
    assert_equal user.id, pref.user_id
  end
end
