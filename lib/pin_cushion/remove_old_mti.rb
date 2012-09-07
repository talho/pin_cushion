module PinCushion
  module RemoveOldMTI 
  
    def RemoveMTIFor(classname, options={})
      options[:superclass_name] ||= classname.superclass.to_s
      options[:class_name] = classname.to_s
      options[:supertable_name] ||= classname.superclass.table_name
      options[:table_name] ||= classname.table_name.gsub('view_','')
      options[:table_prefix] = options[:table_prefix] || "view_"
      DropInheritedTable(options)
    end
    
    protected
    def DropInheritedTable options = {}
      superclass_name = options[:superclass_name]
      class_name = options[:class_name]
      supertable_name = options[:supertable_name]
      table_name = options[:table_name]
      table_prefix = options[:table_prefix]

      # undo our sequence dependency hack
      execute "DELETE FROM pg_constraint
         USING pg_class seq,
         pg_depend dep,
         pg_attribute attr
         WHERE seq.oid = dep.objid
     AND attr.attrelid = dep.refobjid 
                 AND attr.attnum = dep.refobjsubid 
                 AND attr.attrelid = pg_constraint.conrelid
     AND attr.attnum = pg_constraint.conkey[1]
     AND seq.relkind = 'S'
     AND pg_constraint.contype = 'p'
     AND dep.refobjid = '\"#{table_prefix}#{table_name}\"'::regclass;"

      execute "DELETE FROM pg_depend
         USING pg_class seq,
         pg_attribute attr,
         pg_constraint cons,
         pg_depend dep
         WHERE seq.oid = dep.objid
           AND attr.attrelid = dep.refobjid
                 AND attr.attnum = dep.refobjsubid
                 AND attr.attrelid = cons.conrelid
     AND attr.attnum = cons.conkey[1]
     AND seq.relkind = 'S'
     AND cons.contype = 'p'
     AND dep.refobjid = '\"#{supertable_name}\"'::regclass
     AND pg_depend.refobjid = '\"#{table_prefix}#{table_name}\"'::regclass
                 AND dep.classid = pg_depend.classid
                 AND dep.objid = pg_depend.objid
                 AND dep.objsubid = pg_depend.objsubid
                 AND dep.refclassid = pg_depend.refclassid
                 AND dep.refobjsubid = pg_depend.refobjsubid
     AND dep.deptype = pg_depend.deptype;"

      execute "DROP TRIGGER #{table_prefix + table_name}_del_trigger ON #{table_name};"
      execute "DROP FUNCTION #{table_prefix + table_name}_del_function();"
      execute "DROP RULE #{table_prefix + table_name}_del ON #{table_prefix + table_name};"
      execute "DROP RULE #{table_prefix + table_name}_upd ON #{table_prefix + table_name};"
      execute "DROP RULE #{table_prefix + table_name}_ins ON #{table_prefix + table_name};"
      execute "DROP FUNCTION GetInserted#{class_name}(int8);"
      execute "DROP TYPE #{table_prefix + table_name}_type;"
      execute "DROP VIEW #{table_prefix + table_name};"

      #remove_column(supertable_name.to_sym, "#{superclass_name.downcase.to_sym}_type")
    end
  end
end