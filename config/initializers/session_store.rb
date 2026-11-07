# Configure secure session cookies
Rails.application.config.session_store :cookie_store,
  key: "_edgenuity_session",
  expire_after: 24.hours,
  httponly: true,
  same_site: :lax,
  secure: Rails.env.production?
