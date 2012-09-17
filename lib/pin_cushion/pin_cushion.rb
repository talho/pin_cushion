require 'mti'
      
module PinCushion  
  def self.included(base)
    base.send :extend, ClassMethods
  end

  module ClassMethods
    @@pin_cushion_classes = []
    def pin_cushion_classes
      return @@pin_cushion_classes
    end
    
    def acts_as_MTI(additional_table_name = nil)
      #set the table name
      (@additional_table_names ||= []) << (additional_table_name || (self.send :undecorated_table_name, self.to_s)).to_s
      
      @table_name = "view_#{additional_table_name || (self.send :undecorated_table_name, self.to_s)}"
      
      # include the overrides required for MTI. Preferably don't monkeypatch
      self.send :include, PinCushion::MTI
      
      @@pin_cushion_classes << self            
    end
         
    def instantiate(record)
      instance = super(record)
      
      if instance.is_a?(PinCushion::MTI) && record[instance.class.join_column].nil?
        data = Alert.connection.select_one(instance.class.where(id: instance.id).to_sql)
        instance.reinit_with("attributes" => data) unless data.nil?
      end
      instance
    end   
  end
      
  # Override to not break everything whem type has already been set by a class higher up the chain.
  def ensure_proper_type
    klass = self.class
    if klass.finder_needs_type_condition? && read_attribute(klass.inheritance_column).blank?
      write_attribute(klass.inheritance_column, klass.sti_name)
    end
  end
end

ActiveRecord::Base.send :include, PinCushion

require 'engine'


require 'remove_old_mti'
ActiveRecord::Migration.send :include, PinCushion::RemoveOldMTI
require 'create_mti_views'
ActiveRecord::Migration.send :include, PinCushion::CreateMTIViews