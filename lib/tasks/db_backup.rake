namespace :db do
  desc "Perform a safe online SQLite database backup"
  task backup: :environment do
    backup_dir = Rails.root.join("storage", "backups")
    FileUtils.mkdir_p(backup_dir)

    timestamp = Time.now.utc.strftime("%Y%m%d_%H%M%S")
    backup_file = backup_dir.join("backup_#{Rails.env}_#{timestamp}.sqlite3")

    puts "Starting SQLite safe online backup..."
    conn = ActiveRecord::Base.connection
    # VACUUM INTO creates a transactionally consistent copy of the database without locking readers
    conn.execute("VACUUM INTO #{conn.quote(backup_file.to_s)};")

    puts "Backup successfully created at: #{backup_file}"

    # Retention policy: keep last 7 backups, prune older ones
    retention_count = ENV.fetch("BACKUP_RETENTION", 7).to_i
    backups = Dir.glob(backup_dir.join("backup_#{Rails.env}_*.sqlite3")).sort
    if backups.size > retention_count
      prune_list = backups[0...(backups.size - retention_count)]
      prune_list.each do |f|
        File.delete(f)
        puts "Pruned old backup: #{File.basename(f)}"
      end
    end
  end

  desc "Verify database integrity"
  task integrity: :environment do
    conn = ActiveRecord::Base.connection
    result = conn.execute("PRAGMA integrity_check;").first
    status = result["integrity_check"]
    if status == "ok"
      puts "SQLite integrity check passed: OK"
    else
      puts "SQLite integrity check FAILED: #{status}"
      exit 1
    end
  end
end
