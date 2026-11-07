require "test_helper"

class ContactMessageTest < ActiveSupport::TestCase
  test "valid contact message passes validation" do
    msg = ContactMessage.new(
      name: "Alice Smith",
      email: "alice@example.com",
      subject: "Inquiry about Mentorship",
      message: "Hello, I would like to learn more about the mentoring program."
    )
    assert msg.valid?
    assert msg.save
    assert_equal "unread", msg.status
  end

  test "requires all mandatory fields" do
    msg = ContactMessage.new
    assert_not msg.valid?
    assert_includes msg.errors[:name], "can't be blank"
    assert_includes msg.errors[:email], "can't be blank"
    assert_includes msg.errors[:subject], "can't be blank"
    assert_includes msg.errors[:message], "can't be blank"
  end

  test "enforces valid email format" do
    msg = ContactMessage.new(
      name: "Bob",
      email: "not-an-email",
      subject: "Question",
      message: "Testing email validation"
    )
    assert_not msg.valid?
    assert_includes msg.errors[:email], "is invalid"
  end
end
