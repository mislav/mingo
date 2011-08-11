class Mingo
  module Connection
    attr_writer :db, :collection
    
    def db
      (defined?(@db) && @db) or superclass.respond_to?(:db) ? superclass.db : nil
    end

    def connected?
      !!db
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
  end
end
