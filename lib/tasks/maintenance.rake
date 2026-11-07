namespace :maintenance do
  desc "Run all scheduled maintenance tasks (database optimization, backup, cleanup)"
  task run_all: [:optimize_db, "db:backup", :cleanup_old_records] do
    puts "All maintenance tasks completed successfully."
  end

  desc "Run SQLite PRAGMA optimize"
  task optimize_db: :environment do
    puts "Running SQLite database PRAGMA optimize..."
    ActiveRecord::Base.connection.execute("PRAGMA optimize;")
    puts "SQLite optimization complete."
  end

  desc "Clean up archived messages older than 180 days"
  task cleanup_old_records: :environment do
    threshold = 180.days.ago
    deleted_count = ContactMessage.where("status = 'archived' AND updated_at < ?", threshold).delete_all
    puts "Cleaned up #{deleted_count} archived messages older than #{threshold}."
  end
end
