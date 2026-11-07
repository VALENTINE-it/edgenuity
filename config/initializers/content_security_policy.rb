# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :https, :data, "https://fonts.googleapis.com", "https://fonts.gstatic.com"
    policy.img_src     :self, :https, :data, "https://images.unsplash.com"
    policy.object_src  :none
    policy.script_src  :self, :https, :unsafe_inline
    policy.style_src   :self, :https, :unsafe_inline, "https://fonts.googleapis.com"
    policy.connect_src :self
    policy.frame_ancestors :self
  end
end
