module PinCushion
  class Engine < Rails::Engine
    config.after_initialize do
      require File.join(File.dirname(__FILE__), '..', 'active_record', 'persistence')
    end
  end
end