require 'active_support/core_ext/hash/conversions'
require 'mongo'
require 'active_model'

BSON::ObjectId.class_eval do
  def self.[](id)
    self === id ? id : from_string(id)
  end
  
  def id
    self
  end
end

class Mingo < Hash
  include ActiveModel::Conversion
  extend ActiveModel::Translation
  
  autoload :Properties,   'mingo/properties'
  autoload :Cursor,       'mingo/cursor'
  autoload :Connection,   'mingo/connection'
  autoload :Finders,      'mingo/finders'
  autoload :Many,         'mingo/many_proxy'
  autoload :Persistence,  'mingo/persistence'
  autoload :Callbacks,    'mingo/callbacks'
  autoload :Changes,      'mingo/changes'
  autoload :Timestamps,   'mingo/timestamps'
  autoload :Pagination,   'mingo/pagination'
  
  extend Connection
  extend Finders
  # highly experimental stuff
  extend Many

  def initialize(obj = nil)
    super()
    if obj
      # a doc loaded straight from the db?
      if obj['_id'].is_a? BSON::ObjectId then merge!(obj)
      else obj.each { |prop, value| self.send("#{prop}=", value) }
      end
    end
  end

  include Properties
  include Persistence
  include Callbacks
  include Changes
  
  def id
    self['_id']
  end
  
  def ==(other)
    other.is_a?(self.class) and other.id == self.id
  end
end
