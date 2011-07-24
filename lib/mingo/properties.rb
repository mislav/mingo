require 'active_support/concern'

class Mingo
  module Properties
    extend ActiveSupport::Concern

    included do
      instance_variable_set('@properties', Array.new)
    end

    module ClassMethods
      attr_reader :properties

      def property(name, options = {})
        self.properties << name.to_sym

        setter_name = "#{name}="
        unless method_defined?(setter_name)
          class_eval <<-RUBY, __FILE__, __LINE__
            def #{name}(&block)
              self.[](#{name.to_s.inspect}, &block)
            end

            def #{setter_name}(value)
              self.[]=(#{name.to_s.inspect}, value)
            end
          RUBY
        end

        if defined? @subclasses
          @subclasses.each { |klass| klass.property(property_name, options) }
        end
      end

      def inherited(klass)
        super
        (@subclasses ||= Array.new) << klass
        klass.instance_variable_set('@properties', self.properties.dup)
      end
    end

    def inspect
      str = "<##{self.class.to_s}"
      str << self.class.properties.map { |p| " #{p}=#{self.send(p).inspect}" }.join('')
      str << '>'
    end

    def [](field, &block)
      super(field.to_s, &block)
    end

    def []=(field, value)
      super(field.to_s, value)
    end

    def to_hash
      Hash.new.replace(self)
    end

    # keys are already strings
    def stringify_keys!() self end
    def stringify_keys() stringify_keys!.dup end
  end
end
