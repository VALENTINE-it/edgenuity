require "test_helper"

class ContactTest < ActionDispatch::IntegrationTest
  setup do
    RateLimiter.reset!
  end

  test "POST /api/contact saves valid message" do
    assert_difference("ContactMessage.count", 1) do
      post "/api/contact", params: {
        name: "Samantha Ray",
        email: "samantha@example.edu",
        subject: "Physics Mentorship",
        message: "Can I get help preparing for AP Physics exams?"
      }
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert json["message_id"].present?
  end

  test "POST /api/contact rejects invalid data with 422" do
    assert_no_difference("ContactMessage.count") do
      post "/api/contact", params: {
        name: "Sam",
        email: "invalid-email",
        subject: "",
        message: ""
      }
    end

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_equal "VALIDATION_ERROR", json["error"]["code"]
  end

  test "POST /api/contact honeypot silently drops spam without persisting" do
    assert_no_difference("ContactMessage.count") do
      post "/api/contact", params: {
        name: "Bot Spammer",
        email: "spammer@bot.com",
        subject: "Buy links",
        message: "Cheap backlinks",
        website_url: "https://spam-site.com" # Honeypot triggered
      }
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["success"]
  end
end
