require 'mongo'
require 'active_model'
require 'hashie/dash'

BSON::ObjectID.class_eval do
  def self.[](id)
    self === id ? id : from_string(id)
  end
end

class Mingo < Hashie::Dash
  # ActiveModel::Callbacks
  include ActiveModel::Conversion
  extend ActiveModel::Translation
  
  autoload :Cursor, 'mingo/cursor'
  
  class << self
    attr_writer :db, :collection
    
    def db
      @db || superclass.db
    end
    
    def connect(dbname_or_uri)
      self.collection = nil
      self.db = if dbname_or_uri.index('mongodb://') == 0
        connection = Mongo::Connection.from_uri(dbname_or_uri)
        connection.db(connection.auths.last['db_name'])
      else
        Mongo::Connection.new.db(dbname_or_uri)
      end
    end
    
    def collection_name
      self.name
    end
    
    def collection
      @collection ||= db.collection(collection_name).tap { |col|
        col.extend Cursor::CollectionPlugin
      }
    end
    
    def first(id_or_selector = nil, options = {})
      unless id_or_selector.nil? or Hash === id_or_selector
        id_or_selector = BSON::ObjectID[id_or_selector]
      end
      collection.find_one(id_or_selector, {:convert => self}.update(options))
    end
    
    def find(selector = {}, options = {})
      collection.find(selector, {:convert => self}.update(options))
    end
  end
  
  attr_reader :changes
  
  def initialize(obj = nil)
    @changes = Hash.new { |c, key| c[key] = [self[key]] }
    @destroyed = false
    
    if obj and obj['_id'].is_a? BSON::ObjectID
      # a doc loaded straight from the db
      merge!(obj)
    else
      super
    end
  end
  
  def [](property)
    _regular_reader(property.to_s)
  end

  def []=(property, value)
    _regular_writer(property.to_s, value)
  end
  
  def id
    self['_id']
  end
  
  def persisted?
    !!id
  end

  def save(options = {})
    if persisted?
      update(update_values, options)
    else
      self['_id'] = self.class.collection.insert(self.to_hash, options)
    end.
      tap { changes.clear }
  end
  
  def update(doc, options = {})
    self.class.collection.update({'_id' => self.id}, doc, options)
  end
  
  def reload
    doc = self.class.first(id, :convert => nil)
    replace doc
  end

  def destroy
    self.class.collection.remove('_id' => self.id)
    @destroyed = true
    self.freeze
  end
  
  def destroyed?
    @destroyed
  end
  
  def changed?
    changes.any?
  end
  
  private
  
  def update_values
    changes.inject('$set' => {}, '$unset' => {}) do |doc, (key, values)|
      value = values[1]
      value.nil? ? (doc['$unset'][key] = 1) : (doc['$set'][key] = value)
      doc
    end
  end
  
  def _regular_writer(key, value)
    old_value = _regular_reader(key)
    changes[key.to_sym][1] = value unless value == old_value
    super
  end
end

if $0 == __FILE__
  require 'rspec'
  
  Mingo.connect('mingo')

  class User < Mingo
    property :name
    property :age
  end
  
  describe User do
    before :all do
      User.collection.remove
    end
    
    it "tracks changes attribute" do
      user = build
      user.should_not be_persisted
      user.should_not be_changed
      user.name = 'Mislav'
      user.should be_changed
      user.changes.keys.should include(:name)
      user.name = 'Mislav2'
      user.changes[:name].should == [nil, 'Mislav2']
      user.save
      user.should be_persisted
      user.should_not be_changed
      user.id.should be_a(BSON::ObjectID)
    end
    
    it "has a human model name" do
      described_class.model_name.human.should == 'User'
    end
    
    it "can reload values from the db" do
      user = build :name => 'Mislav'
      user.save
      user.update '$unset' => {:name => 1}, '$set' => {:age => 26}
      user.age.should be_nil
      user.reload
      user.age.should == 26
      user.name.should be_nil
    end
    
    it "saves only changed values" do
      user = build :name => 'Mislav', :age => 26
      user.save
      user.update '$inc' => {:age => 1}
      user.name = 'Mislav2'
      user.save
      user.reload
      user.name.should == 'Mislav2'
      user.age.should == 27
    end
    
    it "unsets values set to nil" do
      user = build :name => 'Mislav', :age => 26
      user.save
      user.age = nil
      user.save
      doc = described_class.first(user.id, :convert => nil)
      doc.key?('age').should be_false
      doc.key?('name').should be_true
    end
    
    it "finds a doc by string ID" do
      user = build :name => 'Mislav'
      user.save
      user_dup = described_class.first(user.id.to_s)
      user_dup.id.should == user.id
      user_dup.name.should == 'Mislav'
    end
    
    def build(*args)
      described_class.new(*args)
    end
  end
end