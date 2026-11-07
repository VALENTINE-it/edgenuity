# Puma Web Server Configuration
# Optimized for high concurrency, thread safety, and graceful shutdown

# Max and min thread count per worker process
threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS", 5))
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on; default is 3000
port ENV.fetch("PORT", 3000)

# Environment configuration
environment ENV.fetch("RAILS_ENV") { "development" }

# In production, enable clustered mode with multiple worker processes
# SQLite WAL mode works safely with multiple Puma worker processes
if ENV["RAILS_ENV"] == "production" || ENV["WEB_CONCURRENCY"].to_i > 1
  workers ENV.fetch("WEB_CONCURRENCY", 2).to_i
  preload_app!

  # Allow graceful worker boot and shutdown
  on_worker_boot do
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
  end

  on_worker_shutdown do
    ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
  end
end

# Allow puma to be restarted by `bin/rails restart` command
plugin :tmp_restart

# Specify the PID file
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Worker timeout and graceful shutdown timeouts
worker_timeout 30 if ENV["RAILS_ENV"] == "production"
worker_shutdown_timeout 15
