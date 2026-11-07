require "test_helper"

class AdminTest < ActiveSupport::TestCase
  test "creates admin with valid attributes and hashes password with bcrypt" do
    admin = Admin.new(
      username: "super_admin",
      email: "super@example.com",
      password: "SuperSecretPassword123!",
      password_confirmation: "SuperSecretPassword123!"
    )
    assert admin.valid?
    assert admin.save
    assert admin.authenticate("SuperSecretPassword123!")
    assert_not admin.authenticate("WrongPassword")
    assert admin.password_digest.start_with?("$2a$") || admin.password_digest.start_with?("$2b$")
  end

  test "enforces unique username and email" do
    Admin.create!(
      username: "unique_user",
      email: "unique@example.com",
      password: "Password123!"
    )

    duplicate = Admin.new(
      username: "unique_user",
      email: "other@example.com",
      password: "Password123!"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:username], "has already been taken"

    duplicate_email = Admin.new(
      username: "other_user",
      email: "UNIQUE@example.com",
      password: "Password123!"
    )
    assert_not duplicate_email.valid?
    assert_includes duplicate_email.errors[:email], "has already been taken"
  end

  test "rejects invalid email formats" do
    admin = Admin.new(
      username: "test_admin",
      email: "invalid-email-address",
      password: "Password123!"
    )
    assert_not admin.valid?
    assert_includes admin.errors[:email], "is invalid"
  end
end
