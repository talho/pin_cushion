module PinCushion
  class Engine < Rails::Engine
    config.to_prepare do
      require File.join(File.dirname(__FILE__), '..', 'active_record', 'persistence')
    end
  end
end