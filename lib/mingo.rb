require 'active_support/core_ext/hash/conversions'
require 'mongo'
require 'active_model'
require 'hashie/dash'

BSON::ObjectId.class_eval do
  def self.[](id)
    self === id ? id : from_string(id)
  end
  
  def id
    self
  end
end

class Mingo < Hashie::Dash
  # ActiveModel::Callbacks
  include ActiveModel::Conversion
  extend ActiveModel::Translation
  
  autoload :Cursor, 'mingo/cursor'
  autoload :ManyProxy, 'mingo/many_proxy'
  
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
        id_or_selector = BSON::ObjectId[id_or_selector]
      end
      collection.find_one(id_or_selector, {:convert => self}.update(options))
    end
    
    def find(selector = {}, options = {}, &block)
      collection.find(selector, {:convert => self}.update(options), &block)
    end
    
    def create(obj = nil)
      new(obj).tap { |doc| doc.save }
    end
    
    def many(property, model, &block)
      proxy_class = block_given?? Class.new(ManyProxy, &block) : ManyProxy
      ivar = "@#{property}"
      
      define_method(property) {
        (instance_variable_defined?(ivar) && instance_variable_get(ivar)) ||
          instance_variable_set(ivar, proxy_class.new(self, property, model))
      }
    end
  end
  
  attr_reader :changes
  
  def initialize(obj = nil)
    @changes = {}
    @destroyed = false
    
    if obj and obj['_id'].is_a? BSON::ObjectId
      # a doc loaded straight from the db
      merge!(obj)
    else
      super
    end
  end
  
  # overwrite these to avoid checking for declared properties
  # (which is default behavior in Dash)
  def [](property)
    _regular_reader(property.to_s)
  end

  def []=(property, value)
    _regular_writer(property.to_s, value)
  end
  
  # keys are already strings
  def stringify_keys() self end
  alias :stringify_keys! :stringify_keys
  
  def id
    self['_id']
  end
  
  def persisted?
    !!id
  end

  def save(options = {})
    if persisted?
      update(values_for_update, options)
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
  
  def ==(other)
    other.is_a?(self.class) and other.id == self.id
  end
  
  private
  
  def values_for_update
    changes.inject('$set' => {}, '$unset' => {}) do |doc, (key, values)|
      value = values[1]
      value.nil? ? (doc['$unset'][key] = 1) : (doc['$set'][key] = value)
      doc
    end
  end
  
  def _regular_writer(key, value)
    track_change(key, value)
    super
  end
  
  def track_change(key, value)
    old_value = _regular_reader(key)
    unless value == old_value
      memo = (changes[key.to_sym] ||= [old_value])
      memo[0] == value ? changes.delete(key.to_sym) : (memo[1] = value)
    end
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
    
    it "obtains an ID by saving" do
      user = build :name => 'Mislav'
      user.should_not be_persisted
      user.id.should be_nil
      user.save
      raw_doc(user.id)['name'].should == 'Mislav'
      user.should be_persisted
      user.id.should be_a(BSON::ObjectId)
    end
    
    it "tracks changes attribute" do
      user = build
      user.should_not be_changed
      user.name = 'Mislav'
      user.should be_changed
      user.changes.keys.should include(:name)
      user.name = 'Mislav2'
      user.changes[:name].should == [nil, 'Mislav2']
      user.save
      user.should_not be_changed
    end
    
    it "forgets changed attribute when reset to original value" do
      user = create :name => 'Mislav'
      user.name = 'Mislav2'
      user.should be_changed
      user.name = 'Mislav'
      user.should_not be_changed
    end
    
    it "has a human model name" do
      described_class.model_name.human.should == 'User'
    end
    
    it "can reload values from the db" do
      user = create :name => 'Mislav'
      user.update '$unset' => {:name => 1}, '$set' => {:age => 26}
      user.age.should be_nil
      user.reload
      user.age.should == 26
      user.name.should be_nil
    end
    
    it "saves only changed values" do
      user = create :name => 'Mislav', :age => 26
      user.update '$inc' => {:age => 1}
      user.name = 'Mislav2'
      user.save
      user.reload
      user.name.should == 'Mislav2'
      user.age.should == 27
    end
    
    it "unsets values set to nil" do
      user = create :name => 'Mislav', :age => 26
      user.age = nil
      user.save

      raw_doc(user.id).tap do |doc|
        doc.should_not have_key('age')
        doc.should have_key('name')
      end
    end
    
    context "existing doc" do
      before do
        @id = described_class.collection.insert :name => 'Mislav', :age => 26
      end
      
      it "finds a doc by string ID" do
        user = described_class.first(@id.to_s)
        user.id.should == @id
        user.name.should == 'Mislav'
        user.age.should == 26
      end
    
      it "is unchanged after loading" do
        user = described_class.first(@id)
        user.should_not be_changed
        user.age = 27
        user.should be_changed
        user.changes.keys.should == [:age]
      end
    
      it "doesn't get changed by an inspect" do
        user = described_class.first(@id)
        # triggers AS stringify_keys, which dups the Dash and writes to it,
        # which mutates the @changes hash from the original Dash
        user.inspect
        user.should_not be_changed
      end
    end
    
    it "returns nil for non-existing doc" do
      doc = described_class.first('nonexist' => 1)
      doc.should be_nil
    end
    
    it "compares with another record" do
      one = create :name => "One"
      two = create :name => "Two"
      one.should_not == two
      
      one_dup = described_class.first(one.id)
      one_dup.should == one
    end
    
    def build(*args)
      described_class.new(*args)
    end
    
    def create(*args)
      described_class.create(*args)
    end
    
    def raw_doc(selector)
      described_class.first(selector, :convert => nil)
    end
  end
end
