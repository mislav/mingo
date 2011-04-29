require 'will_paginate/finders/base'

class Mingo
  module Pagination
    def self.extended(base)
      klass = base::Cursor
      unless klass.instance_methods.map(&:to_sym).include? :paginate
        klass.send(:include, PaginatedCursor)
      end
    end
    
    def paginate(options)
      find.paginate(options)
    end
    
    module PaginatedCursor
      include WillPaginate::Finders::Base

      def wp_query(options, pager, args)
        self.limit pager.per_page
        self.skip pager.offset
        self.sort options[:sort]
        pager.replace self.to_a
        pager.total_entries = self.count unless pager.total_entries
      end
    end
  end
  
  extend Pagination
end
