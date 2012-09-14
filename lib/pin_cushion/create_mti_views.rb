module PinCushion
  module CreateMTIViews
    def create_mti_view klass
      execute "CREATE OR REPLACE VIEW #{klass.table_name} AS #{klass.mti_view_sql}"
    end
    
    # we're just going to go through and create all of the MTI views
    def create_mti_views
      ActiveRecord::Base.pin_cushion_classes.each do |klass|
        create_mti_view klass
      end
    end
    
    
    def drop_mti_view klass_or_string
      execute "DROP VIEW #{klass_or_string.is_a? PinCushion::MTI ? klass_or_string.table_name : klass_or_string}"
    end  
    
    def drop_mti_views
      ActiveRecord::Base.pin_cushion_classes.each do |klass|
        drop_mti_view klass
      end
    end  
  end
end