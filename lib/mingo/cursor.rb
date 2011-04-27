class Mingo
  # Custom Cursor subclass.
  # TODO: contribute this to the official driver
  class Cursor < Mongo::Cursor
    module CollectionPlugin
      def find(*args)
        cursor = Cursor.from_mongo(super(*args))
        
        if block_given?
          yield cursor
          cursor.close()
          nil
        else
          cursor
        end
      end
    end
    
    def self.from_mongo(cursor)
      new(cursor.collection).tap do |sub|
        cursor.instance_variables.each { |ivar|
          sub.instance_variable_set(ivar, cursor.instance_variable_get(ivar))
        }
      end
    end
    
    def empty?
      !has_next?
    end
  end
end
