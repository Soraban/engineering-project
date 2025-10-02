if defined?(Bullet)
  Bullet.enable = true
  Bullet.bullet_logger = true
  Bullet.rails_logger = true
  Bullet.add_footer = true if Rails.env.development?

  # Detect N+1 queries
  Bullet.alert = false
  Bullet.console = true

  # Detect unused eager loading
  Bullet.unused_eager_loading_enable = true

  # Detect counter cache
  Bullet.counter_cache_enable = true
end
