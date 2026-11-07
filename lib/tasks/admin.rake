namespace :admin do
  desc "Create an administrator account (usage: bin/rails admin:create[username,email,password])"
  task :create, [:username, :email, :password] => :environment do |_, args|
    username = args[:username] || ENV["ADMIN_USERNAME"]
    email = args[:email] || ENV["ADMIN_EMAIL"]
    password = args[:password] || ENV["ADMIN_PASSWORD"]

    if username.blank? || email.blank? || password.blank?
      puts "Usage: bin/rails admin:create[username,email,password]"
      exit 1
    end

    admin = Admin.new(
      username: username,
      email: email,
      password: password,
      password_confirmation: password,
      role: "admin"
    )

    if admin.save
      puts "Successfully created administrator: #{admin.username} (#{admin.email})"
    else
      puts "Failed to create administrator:"
      admin.errors.full_messages.each { |msg| puts "  - #{msg}" }
      exit 1
    end
  end

  desc "List all administrator accounts"
  task list: :environment do
    admins = Admin.all
    puts "Total administrators: #{admins.count}"
    admins.each do |admin|
      puts "ID: #{admin.id} | User: #{admin.username} | Email: #{admin.email} | Role: #{admin.role} | Last login: #{admin.last_login_at || 'Never'}"
    end
  end

  desc "Reset an administrator password (usage: bin/rails admin:reset_password[username,new_password])"
  task :reset_password, [:username, :new_password] => :environment do |_, args|
    admin = Admin.find_by(username: args[:username].to_s.strip.downcase)
    if admin.nil?
      puts "Error: Admin '#{args[:username]}' not found."
      exit 1
    end

    admin.password = args[:new_password]
    admin.password_confirmation = args[:new_password]
    if admin.save
      puts "Successfully updated password for administrator #{admin.username}"
    else
      puts "Failed to update password: #{admin.errors.full_messages.join(', ')}"
      exit 1
    end
  end
end
