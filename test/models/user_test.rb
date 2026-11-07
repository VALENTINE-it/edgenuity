require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "creates user with valid attributes and hashes password with bcrypt" do
    user = User.new(
      name: "Marcus Aurelius",
      email: "marcus@philosophy.edu",
      password: "SecureStudentPass123!",
      password_confirmation: "SecureStudentPass123!"
    )
    assert user.valid?
    assert user.save
    assert user.authenticate("SecureStudentPass123!")
    assert_not user.authenticate("WrongPassword")
    assert user.password_digest.start_with?("$2a$") || user.password_digest.start_with?("$2b$")
  end

  test "enforces unique email address case-insensitively" do
    User.create!(
      name: "Student One",
      email: "student@school.edu",
      password: "Password123!"
    )

    duplicate = User.new(
      name: "Student Two",
      email: "STUDENT@school.edu",
      password: "Password123!"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "normalizes and downcases email address" do
    user = User.create!(
      name: "  Sarah Connor  ",
      email: "  SARAH.CONNOR@SKYNET.ORG  ",
      password: "Password123!"
    )
    assert_equal "Sarah Connor", user.name
    assert_equal "sarah.connor@skynet.org", user.email
  end

  test "provides first_name and initials helper methods" do
    user = User.new(name: "Elena Rostova")
    assert_equal "Elena", user.first_name
    assert_equal "ER", user.initials
  end
end
