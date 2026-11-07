require "test_helper"

class HealthTest < ActionDispatch::IntegrationTest
  test "GET /health/live returns HTTP 200 with alive status" do
    get "/health/live"
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert_equal "alive", json["status"]
    assert_equal "edgenuity-backend", json["service"]
    assert json["timestamp"].present?
  end

  test "GET /health/ready returns HTTP 200 and connected status" do
    get "/health/ready"
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert_equal "ready", json["status"]
    assert_equal "connected", json["database"]
  end

  test "GET /api/metrics returns system metrics and database connection stats" do
    get "/api/metrics"
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert json["metrics"].key?("database")
    assert json["metrics"].key?("models")
    assert json["metrics"]["models"].key?("mentors_count")
  end
end
