class Mingo
  # TODO: contribute this to the official driver
  class Cursor < Mongo::Cursor
    module CollectionPlugin
      def find(selector={}, opts={})
        opts = opts.dup
        convert = opts.delete(:convert)
        cursor = Cursor.from_mongo(super(selector, opts), convert)
        
        if block_given?
          yield cursor
          cursor.close()
          nil
        else
          cursor
        end
      end
    end
    
    def self.from_mongo(cursor, convert)
      new(cursor.collection, :convert => convert).tap do |sub|
        cursor.instance_variables.each { |ivar|
          sub.instance_variable_set(ivar, cursor.instance_variable_get(ivar))
        }
      end
    end
    
    def initialize(collection, options={})
      super
      @convert = options[:convert]
    end
    
    def next_document
      convert_document super
    end
    
    private
    
    def convert_document(doc)
      if @convert.nil? or doc.nil? then doc
      elsif @convert.respond_to?(:call) then @convert.call(doc)
      else @convert.new(doc)
      end
    end
  end
end
