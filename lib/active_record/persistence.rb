module ActiveRecord
  module Persistence   
    
    alias :destroy_original :destroy
        
    # Destroy the row by calling raw SQL on this row. With MTI, should delete from each additional table.
    def destroy
      self.class.send :delete_additional_tables, id if self.is_a?(PinCushion::MTI) && persisted?
      destroy_original # Finish by calling the base method    
    end
    
    private
       
    alias :update_original :update
    # Update attributes for each additional table separately
    def update(attribute_names = @attributes.keys)
      #Call original update with keys in the base table
      if self.is_a? PinCushion::MTI
        klass = self.class
        update_original(attribute_names & klass.columns_table_hash[klass.table_name].map(&:name))
        
        #Now do the process with the rest of the keys
        klass.additional_table_names.each do |table|
          arel = Arel::Table.new(table, self)
          attributes_with_values = arel_attributes_values(false, false, attribute_names & klass.columns_table_hash[table].map(&:name) - [klass.join_column], arel)
          next if attributes_with_values.empty?
          stmt = arel.where(arel[klass.join_column].eq(id)).compile_update(attributes_with_values)
          klass.connection.update stmt
        end
      else
        update_original attribute_names
      end     
    end
    
    alias :create_original :create
    # Create for the main table and then each additional table separately
    def create
      create_original
              
      if self.is_a? PinCushion::MTI  
        klass = self.class        
        # ensure the join column is set
        self[klass.join_column] = self.id
  
        #write out the remainder of the columns
        klass.additional_table_names.each do |table|
          arel = Arel::Table.new(table, self)
          attributes_with_values = arel_attributes_values(false, true, klass.columns_table_hash[table].map(&:name), arel)
          next if attributes_with_values.empty?
          stmt = arel.where(arel[klass.join_column].eq(id)).compile_insert(attributes_with_values)
          klass.connection.create stmt
        end
      end
        
      self.id
    end
  end
end