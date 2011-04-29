class Mingo
  module Finders
    def first(id_or_selector = nil, options = {})
      unless id_or_selector.nil? or Hash === id_or_selector
        id_or_selector = BSON::ObjectId[id_or_selector]
      end
      options = { :transformer => lambda {|doc| self.new(doc)} }.update(options)
      collection.find_one(id_or_selector, options)
    end
    
    def find(selector = {}, options = {}, &block)
      options = { :transformer => lambda {|doc| self.new(doc)} }.update(options)
      collection.find(selector, options, &block)
    end
    
    def find_by_ids(object_ids, query = {}, options = {})
      find({:_id => {'$in' => object_ids}}.update(query), options)
    end
    
    def find_ordered_ids(object_ids, query = {}, options = {})
      indexed = find_by_ids(object_ids, query, options).inject({}) do |hash, object|
        hash[object.id] = object
        hash
      end
      
      object_ids.map { |id| indexed[id] }
    end
    
    def paginate_ids(object_ids, paginate_options, options = {})
      object_ids.paginate(paginate_options).tap do |collection|
        collection.replace find_ordered_ids(collection, {}, options)
      end
    end
  end
end
