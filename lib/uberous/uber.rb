module Uberous
  class Uber
    attr_reader :data_collection, :error_data_collection, :version
    def initialize(data_collection = [], error_data_collection = [], version = '1.0')
      @data_collection = data_collection
      @error_data_collection = error_data_collection
      @version = version
    end

    def add_data(data)
      @data_collection << data
    end

    def add_error_data(data)
      @error_data_collection << data
    end

    def add_link(rel, url, options = {})
      link = Data.new(options.merge(rel: rel, url: url))
      add_data(link)
    end

    def to_hash
      data = @data_collection.map(&:to_hash)
      error = @error_data_collection.map(&:to_hash)
      uber = { version: @version }
      uber[:data] = data unless data.empty?
      uber[:error] = error unless error.empty?
      { uber: uber }
    end
  end

  class Data
    ATTR_NAMES = [:id, :name, :rel, :url, :action, :transclude, :model, :sending, :accepting, :value].freeze
    attr_reader :data_collection
    def initialize(attrs = {})
      @attrs = ATTR_NAMES.each_with_object({}) {|name, h| h[name] = attrs[name] if attrs.has_key?(name) } # slice
      @data_collection = Array(attrs[:data_collection])
    end

    ATTR_NAMES.each do |attr_name|
      define_method(attr_name) do
        @attrs[attr_name]
      end
      define_method("#{attr_name}=") do |value|
        @attrs[attr_name] = value
      end
    end

    def add_data(data)
      @data_collection << data
    end

    def add_link(rel, url, options = {})
      link = Data.new(options.merge(rel: rel, url: url))
      add_data(link)
    end

    def to_hash
      hash = @attrs.dup
      data = @data_collection.map(&:to_hash)
      hash[:data] = data unless data.empty?
      hash
    end
  end

  class Loader
    attr_reader :uber
    def initialize(hash)
      uber_hash = hash['uber']
      @uber_data_hashes = uber_hash.fetch('data', [])
      @uber_error_data_hashes = uber_hash.fetch('error', [])
      @uber = Uber.new([], [], uber_hash['version'])

      load_data
      load_error_data
    end

    def load_data
      @uber_data_hashes.each do |uber_data_hash|
        @uber.add_data(hash_to_data(uber_data_hash))
      end
    end

    def load_error_data
      @uber_error_data_hashes.each do |uber_error_data_hash|
        @uber.add_data(hash_to_data(uber_error_data_hash))
      end
    end

    def hash_to_data(hash)
      data_hash = {}
      hash.each do |k, v|
        data_hash[(k.to_sym rescue k)] = v # symbolize_keys
      end
      child_data_hashes = data_hash.delete(:data) || []
      data = Data.new(data_hash)
      child_data_hashes.each do |child_data_hash|
        data.add_data(hash_to_data(child_data_hash))
      end
      data
    end
  end
end
