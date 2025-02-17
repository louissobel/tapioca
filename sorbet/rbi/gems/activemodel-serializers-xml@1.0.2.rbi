# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `activemodel-serializers-xml` gem.
# Please instead update this file by running `bin/tapioca gem activemodel-serializers-xml`.

module ActiveModel
  class << self
    def eager_load!; end
    def gem_version; end
    def version; end
  end
end

module ActiveModel::Serializers; end

module ActiveModel::Serializers::Xml
  include ::ActiveModel::Serialization
  extend ::ActiveSupport::Concern

  mixes_in_class_methods ::ActiveModel::Naming

  # Sets the model +attributes+ from an XML string. Returns +self+.
  #
  #   class Person
  #     include ActiveModel::Serializers::Xml
  #
  #     attr_accessor :name, :age, :awesome
  #
  #     def attributes=(hash)
  #       hash.each do |key, value|
  #         instance_variable_set("@#{key}", value)
  #       end
  #     end
  #
  #     def attributes
  #       instance_values
  #     end
  #   end
  #
  #   xml = { name: 'bob', age: 22, awesome:true }.to_xml
  #   person = Person.new
  #   person.from_xml(xml) # => #<Person:0x007fec5e3b3c40 @age=22, @awesome=true, @name="bob">
  #   person.name          # => "bob"
  #   person.age           # => 22
  #   person.awesome       # => true
  def from_xml(xml); end

  # Returns XML representing the model. Configuration can be
  # passed through +options+.
  #
  # Without any +options+, the returned XML string will include all the
  # model's attributes.
  #
  #   user = User.find(1)
  #   user.to_xml
  #
  #   <?xml version="1.0" encoding="UTF-8"?>
  #   <user>
  #     <id type="integer">1</id>
  #     <name>David</name>
  #     <age type="integer">16</age>
  #     <created-at type="dateTime">2011-01-30T22:29:23Z</created-at>
  #   </user>
  #
  # The <tt>:only</tt> and <tt>:except</tt> options can be used to limit the
  # attributes included, and work similar to the +attributes+ method.
  #
  # To include the result of some method calls on the model use <tt>:methods</tt>.
  #
  # To include associations use <tt>:include</tt>.
  #
  # For further documentation, see <tt>ActiveRecord::Serialization#to_xml</tt>
  def to_xml(options = T.unsafe(nil), &block); end
end

class ActiveModel::Serializers::Xml::Serializer
  # @return [Serializer] a new instance of Serializer
  def initialize(serializable, options = T.unsafe(nil)); end

  # Returns the value of attribute options.
  def options; end

  def serializable_collection; end
  def serializable_hash; end
  def serialize; end

  private

  # TODO: This can likely be cleaned up to simple use ActiveSupport::XmlMini.to_tag as well.
  def add_associations(association, records, opts); end

  def add_attributes_and_methods; end
  def add_extra_behavior; end
  def add_includes; end
  def add_procs; end
end

class ActiveModel::Serializers::Xml::Serializer::Attribute
  # @return [Attribute] a new instance of Attribute
  def initialize(name, serializable, value); end

  def decorations; end

  # Returns the value of attribute name.
  def name; end

  # Returns the value of attribute type.
  def type; end

  # Returns the value of attribute value.
  def value; end

  protected

  def compute_type; end
end

class ActiveModel::Serializers::Xml::Serializer::MethodAttribute < ::ActiveModel::Serializers::Xml::Serializer::Attribute; end
