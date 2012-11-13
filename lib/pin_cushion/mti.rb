module PinCushion  
  module MTI
    def self.included(base)      
      base.class_eval do
        extend ClassMethods
        
        reset_column_information
      end      
    end
    
    module ClassMethods
      def mti_view_sql
        ["SELECT #{self.columns_table_hash.map{|k, v| v.map { |c| "#{k}.#{c.name}"} }.reject(&:blank?).join(',')}",
         "FROM #{self.base_table_name}",
         self.additional_table_names.map do |table|
           ActiveRecord::Base.connection.table_exists?(table) ? "JOIN #{table} ON #{self.base_table_name}.id = #{table}.#{self.join_column}" : '' 
         end.reject(&:blank?).join(' ')
        ].join(' ')
      end
      
      def table_name
        @table_name || self.superclass.table_name || super
      end
      
      def base_table_name
        @base_table_name ||= self.superclass.respond_to?(:base_table_name) ? self.superclass.base_table_name : self.superclass.table_name
      end
      
      def columns
        @columns ||= columns_table_hash.values.flatten
      end
                     
      def columns_table_hash
        @columns_table_hash ||= begin
                    
          if self.superclass.is_a? PinCushion::MTI
            columns_table_hash = self.superclass.columns_table_hash
          else
            columns_table_hash = HashWithIndifferentAccess.new 
            columns_table_hash[self.base_table_name] = self.superclass.columns
          end
          
          additional_table_names.each do |table_name|
            columns_table_hash[table_name] = connection.schema_cache.columns[table_name].map do |col|
              col.dup
            end.select { |c| columns_table_hash.values.flatten.index {|v| c.name == v.name }.nil? } if ActiveRecord::Base.connection.table_exists? table_name
          end unless @additional_table_names.nil?
          
          columns_table_hash
        end        
      end
      
      def direct_ancestors
        @direct_ancestors ||= begin
          c = self
          a = []
          while c.superclass
            a << c.superclass 
            c = c.superclass
          end
          a
        end
      end
      
      def additional_table_names
        @additional_table_names ||= []
      end
      
      def join_column
        "#{self.base_table_name.singularize}_id"
      end
          
      def delete(id_or_array)
        self.send :delete_additional_tables, id_or_array
        self.superclass.delete(id_or_array)
      end
            
      protected
  
      def delete_additional_tables(id_or_array)  
        klass = self
        klass.additional_table_names.each do |table|
          arel = Arel::Table.new(table, self)
          stmt = arel.where(id_or_array.is_a?(Array) ? arel[klass.join_column].in(id_or_array) : arel[klass.join_column].eq(id_or_array)).compile_delete()
          klass.connection.delete stmt
        end
      end          
    end
    
    # becomes overwrites the value of the inheritance column. This isn't the behavior that we want. Becomes also has a bug in 3.2. Go ahead and override the entire thing until 3.2.9 comes out with it fixed.
    def becomes(klass)
      became = klass.new
      became.instance_variable_set("@attributes", @attributes)
      became.instance_variable_set("@attributes_cache", @attributes_cache)
      became.instance_variable_set("@new_record", new_record?)
      became.instance_variable_set("@destroyed", destroyed?)
      became.instance_variable_set("@errors", errors)
      became
    end    
         
    protected
        
    def arel_attributes_values(include_primary_key = true, include_readonly_attributes = true, attribute_names = self.class.columns_table_hash[self.class.base_table_name].map(&:name), attribute_table = self.class.arel_table)
      attrs      = {}
      klass      = self.class
      arel_table = attribute_table

      attribute_names.each do |name|
        if (column = column_for_attribute(name)) && (include_primary_key || !column.primary)

          if include_readonly_attributes || !klass.readonly_attributes.include?(name)

            value = if klass.serialized_attributes.include?(name)
                      @attributes[name].serialized_value
                    else
                      # FIXME: we need @attributes to be used consistently.
                      # If the values stored in @attributes were already type
                      # casted, this code could be simplified
                      read_attribute(name)
                    end

            attrs[arel_table[name]] = value
          end
        end
      end

      attrs
    end  
                
  end
end