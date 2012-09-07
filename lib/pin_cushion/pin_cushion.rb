module PinCushion
  def self.included(base)
    base.send :extend, ClassMethods
  end

  module ClassMethods
    def acts_as_MTI(additional_table_name = nil)
      #set the table name
      (@additional_table_names ||= []) << (additional_table_name || (self.send :undecorated_table_name, self.to_s)).to_s
      
      # include the overrides required for MTI. Preferably don't monkeypatch
      require 'mti'
      self.send :include, PinCushion::MTI            
    end
    
     
    def instantiate(record)
      instance = super(record)
      
      if instance.is_a?(PinCushion::MTI) && record[instance.class.join_column].nil?
        instance.reinit_with("attributes" => Alert.connection.select_one(instance.class.where(id: instance.id).to_sql))
      end
      instance
    end   
  end
end

ActiveRecord::Base.send :include, PinCushion

require 'engine'


require 'remove_old_mti'
ActiveRecord::Migration.send :extend, PinCushion::RemoveOldMTI