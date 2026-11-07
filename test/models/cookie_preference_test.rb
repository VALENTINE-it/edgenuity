require "test_helper"

class CookiePreferenceTest < ActiveSupport::TestCase
  test "creates valid cookie preference with default essential true" do
    pref = CookiePreference.new(
      visitor_token: "v_token_123456",
      consent_status: "accepted",
      essential: true,
      functional: true,
      analytics: true,
      personalization: true,
      consented_at: Time.now.utc
    )
    assert pref.valid?
    assert pref.save
    assert pref.functional_allowed?
    assert pref.analytics_allowed?
    assert pref.personalization_allowed?
  end

  test "validates inclusion of consent_status" do
    pref = CookiePreference.new(
      visitor_token: "v_token_123456",
      consent_status: "invalid_status",
      consented_at: Time.now.utc
    )
    assert_not pref.valid?
    assert_includes pref.errors[:consent_status], "is not included in the list"
  end

  test "denied consent restricts optional categories" do
    pref = CookiePreference.create!(
      visitor_token: "v_token_denied",
      consent_status: "denied",
      essential: true,
      functional: false,
      analytics: false,
      personalization: false,
      consented_at: Time.now.utc
    )
    assert_not pref.functional_allowed?
    assert_not pref.analytics_allowed?
    assert_not pref.personalization_allowed?
  end
end
