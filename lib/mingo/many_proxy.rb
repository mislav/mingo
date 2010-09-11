class Mingo
  class ManyProxy
    def self.decorate_with(mod = nil, &block)
      if mod or block_given?
        @decorate_with = mod || Module.new(&block)
      else
        @decorate_with
      end
    end
    
    def self.decorate_each(&block)
      if block_given?
        @decorate_each = block
      else
        @decorate_each
      end
    end
    
    def initialize(parent, property, model)
      @parent = parent
      @property = property
      @model = model
      @collection = nil
      @embedded = (@parent[@property] ||= [])
      @parent.changes.delete(@property)
    end
    
    def find_options
      @find_options ||= begin
        decorator = self.class.decorate_with
        decorate_block = self.class.decorate_each
        
        if decorator or decorate_block
          {:convert => lambda { |doc|
            @model.new(doc).tap do |obj|
              obj.extend decorator if decorator
              decorate_block.call(obj, @embedded) if decorate_block
            end
          }}
        else
          {}
        end
      end
    end
  
    undef :to_a, :inspect
  
    def object_ids
      @embedded
    end
    
    def include?(doc)
      object_ids.include? convert(doc)
    end
  
    def convert(doc)
      doc.id
    end
  
    def <<(doc)
      doc = convert(doc)
      @parent.update '$addToSet' => { @property => doc }
      unload_collection
      @embedded << doc
      self
    end
  
    def delete(doc)
      doc = convert(doc)
      @parent.update '$pull' => { @property => doc }
      unload_collection
      @embedded.delete doc
    end
    
    def loaded?
      !!@collection
    end
  
    private
  
    def method_missing(method, *args, &block)
      load_collection
      @collection.send(method, *args, &block)
    end
  
    def unload_collection
      @collection = nil
    end
  
    def load_collection
      @collection ||= if @embedded.empty? then []
      else @model.find({:_id => {'$in' => self.object_ids}}, find_options)
      end
    end
  end
end