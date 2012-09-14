module ActiveRecord
  module Persistence   
    
    private
    alias :destroy_original :destroy
        
    public
    # Destroy the row by calling raw SQL on this row. With MTI, should delete from each additional table.
    def destroy
      if self.is_a? PinCushion::MTI
        self.class.send :delete_additional_tables, id if self.is_a?(PinCushion::MTI) && persisted?
        # we have to be mindful here of the callbacks. We've broken down below the level of callbacks, so if
        # we were to just call destroy on the superclass, we would likely trigger a second set of callbacks.
        # Instead, we're going to call either this method or the original with the context of the superclass
        # depending on if superclass is MTI or regular
        sup_object = self.becomes(self.class.superclass)      
        ActiveRecord::Persistence.instance_method(:destroy).bind(sup_object).call # Finish by calling the base method
      else
        destroy_original
      end   
    end
    
    private
       
    alias :update_original :update
    # Update attributes for each additional table separately
    def update(attribute_names = @attributes.keys)
      if self.is_a? PinCushion::MTI
        klass = self.class
        sup_object = self.becomes(klass.superclass)
        ActiveRecord::Persistence.instance_method(:update).bind(sup_object).call(attribute_names & klass.superclass.columns.map(&:name))
        
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
      if self.is_a? PinCushion::MTI
        klass = self.class        
        
        sup_object = self.becomes(klass.superclass)
        ActiveRecord::Persistence.instance_method(:create).bind(sup_object).call
          
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
        
        IdentityMap.add(self) if IdentityMap.enabled?
        @new_record = false # This is something the base create does, but since it's doing it on a different instance of the class, it's never being set for our instance. Set it now.
        
        self.id
      else        
        create_original
      end
    end
  end
end