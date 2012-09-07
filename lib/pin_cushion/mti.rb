module PinCushion  
  module MTI
    def self.included(base)
      base.class_eval do
        extend ClassMethods
        
        reset_column_information
        
        # class << self
          # alias_method_chain :columns, :super
        # end        
        
        default_scope select(self.columns_table_hash.map{|k, v| v.map { |c| "#{k}.#{c.name}"} }.reject(&:blank?).join(','))
                      .joins(self.additional_table_names.map do |table|
                        "JOIN #{table} ON #{self.table_name}.id = #{table}.#{self.join_column}"
                      end.reject(&:blank?).join(' '))
                         
      end      
    end
    
    module ClassMethods
      def columns
        @columns ||= begin
          @columns_table_hash = HashWithIndifferentAccess.new 
          @columns_table_hash[self.table_name] = super
          
          self.additional_table_names.each do |table_name|
            @columns_table_hash[table_name] = connection.schema_cache.columns[table_name].map do |col|
              col.dup
            end.select { |c| @columns_table_hash.values.flatten.index {|v| c.name == v.name }.nil? }
          end
          
          @columns_table_hash.values.flatten
        end
      end
            
      def columns_table_hash
        # force calculation of base_columns 
        columns
        @columns_table_hash || {}
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
        (@additional_table_names ||= []) | (self.superclass.respond_to?(:additional_table_names) ? self.superclass.additional_table_names : [])
      end
      
      def join_column
        "#{self.table_name.singularize}_id"
      end
          
      def delete(id_or_array)
        self.send :delete_additional_tables, id_or_array
        super
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
     
    protected
    
    def arel_attributes_values(include_primary_key = true, include_readonly_attributes = true, attribute_names = self.class.columns_table_hash[self.class.table_name].map(&:name), attribute_table = self.class.arel_table)
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