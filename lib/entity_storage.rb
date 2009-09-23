$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
  
require 'rubygems'
require 'activerecord'

module EntityStorage
  VERSION = '1.0.3'
  
  class Storage
    attr_accessor :defaults
    
    # Checks for the existence of the necessary Entities table... if not here, creates it.
    def initialize(defaults={})
      unless ActiveRecord::Base.connection.table_exists?('entity_storage')
				AddEntitiesTable.up
      end

      self.defaults = defaults
    end
    
    # Read a value.
    def [](index)
      Entity.get_value(index,defaults[index])
    end
    
    # Write a value.
    def []=(index,value)
      Entity.set_value(index,value)
    end
    
    # Deletes a key and associated data from store.
    def delete(index)
      Entity.remove_item(index)
    end
    
    # Returns the default value of a key contained in DEFAULT_KEYS global constant.
    # Does not change the stored value. Use default! to reset the value.
    def default(index)
      self.defaults[:index]
    end
  
    # Resets the default value of a key contained in DEFAULT_KEYS global constant and returns the value.
    def default!(index)
      Entity.reset_value(index,defaults[index])
    end
    
    # Allows EntityStorage[:whatever] to be accessed via EntityStorage.whatever.
    def method_missing(*args)
      if args.length == 1
	  self[args[0]]
	elsif args.length == 2 and args[0].to_s =~ /^(.*)=$/
	  self[$1.intern] = args[1]
	else
	  super
	end
    end
  end
  
  # This migration is required for EntityStorage to work correctly
  class AddEntitiesTable < ActiveRecord::Migration
    def self.up
      create_table "entity_storage", :force => true do |t|
	t.string   "key",        :limit => 512, :null => false
	t.text     "value"
	t.datetime "created_at"
	t.datetime "updated_at"
      end
    
      add_index "entity_storage", ["created_at"], :name => "created_at"
      add_index "entity_storage", ["key"], :name => "key"
      add_index "entity_storage", ["updated_at"], :name => "updated_at"
    end
    
    def self.down
      drop_table :entities
    end
  end
  
  
  class Entity < ActiveRecord::Base
    set_table_name "entity_storage"
    
    # Entities should be used via class methods and not instantiated directly.
    private_class_method :new
    
    # Gets value based on specific key.
    # If not found, will initialize according to defaults set in DEFAULT_KEYS global constant.
    def self.get_value(search_key,default_value)
      e = Entity.find_by_key(search_key.to_s)
      if e.nil?
				e = initialize_value(search_key,default_value)
      end
      e.value rescue nil
    end
    
    # Sets value for a specific key. If key doesn't exist, creates with value. 
    def self.set_value(search_key, new_value)
      e = Entity.find_by_key(search_key.to_s)
      if e.nil?
				e = new
      end
      e.key = search_key
      e.value = new_value
      e.save
    end
    
    # Resets a key contained in DEFAULT_KEYS global constant to it's default value
    def self.reset_value(search_key,default_value)
      Entity.remove_item(search_key)
      initialize_value(search_key,default_value).value   
    end
    
    # Deletes a record from key store.
    def self.remove_item(search_key)
      e = Entity.find_by_key(search_key.to_s)
      e.destroy rescue 0
    end
    
    def value=(data)
      write_attribute(:value,Marshal.dump(data))
    end
    
    def value
      Marshal.load(read_attribute(:value))
    end
    
    def key=(newkey)
      write_attribute(:key,newkey.to_s)
    end
    
    private
    
    # Checks provided key against internal defaults list and initializes to default value.
    # Defaults defined in DEFAULT_KEYS global constant.
    def self.initialize_value(search_key,default_value)
      en = new
      en.key = search_key
      en.value = default_value
      en.save
      en
    end
    
  end

end

