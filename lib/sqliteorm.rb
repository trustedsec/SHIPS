require 'sqlite3'
require 'thread'

module SQLiteORM
  
  def self.included(base)
    base.extend(StaticMethods)
    base.send(:private, :statement_generator)
    base.send(:private, :migrate)
  end
  
  def statement_generator(opperation=:select)
    names = instance_variables.map { |x| x.to_s[1..-1] }
    sql = ''
    case opperation
    when :select
      sql = "SELECT #{ names.join(',') } FROM #{ self.class.name } WHERE id = ?"
    when :insert
      sql = "INSERT INTO #{ self.class.name } (#{ names.join(',') }) VALUES (#{ Array.new(names.count,'?').join(',') })"
    when :update
      sql = "UPDATE #{ self.class.name } SET "
      sql = sql + (names.map { |x| "#{x} = ?"}.join(',')) + "WHERE id = ?"
    when :delete
      sql = "DELETE FROM #{ self.class.name } WHERE id = ?"
    end
    sql
  end
  
  def migrate
    #ugly hack for MRI ruby behavior
    #why is this different on jruby?
    @@database = self.class.class_variable_get(:@@database)
    @@sync = self.class.class_variable_get(:@@sync)
  end 
  
  def delete
    migrate #hack
    raise RuntimeError, "#{self.class.name} model not connected to database" unless defined?(@@sync)
    @@sync.synchronize { @@database.get_first_row(statement_generator(:delete), [@id]) }
    nil 
  end
  
  def load(id=nil)
    migrate #hack
    id = @id unless id
    raise ArgumentError, "No object reference, id is required" unless id
    raise RuntimeError, "#{self.class.name} model not connected to database" unless defined?(@@sync)
    row = nil
    @@sync.synchronize { row = @@database.get_first_row(statement_generator(:select), [id]) } 
    return nil unless row
    ivs = instance_variables
    ivs.count.times { |i| instance_variable_set(ivs[i], row[i]) }
    return self #allows obj = ClassName.new.load(id)
  end
  
  def save
    migrate #hack
    raise RuntimeError, "#{self.class.name} model not connected to database" unless defined?(@@sync)
    @@sync.synchronize do
      if @@database.get_first_value("SELECT id FROM #{self.class.name} WHERE id = ?", [@id])   
       @@database.execute(statement_generator(:update), instance_variables.map {|x| instance_variable_get(x)} + [@id])  
      else
       @@database.execute(statement_generator(:insert), instance_variables.map {|x| instance_variable_get(x)})
      end
    end
    return self
  end
  
  module StaticMethods
    def db_connection=(v) 
      raise ArgumentError, 'Expected Sqlite3::Database' unless v.kind_of?(SQLite3::Database)
      self.class_variable_set(:@@database,  v)
      self.class_variable_set(:@@sync, Mutex.new)
    end
    
    def each
      results = nil
      self.class_variable_get(:@@sync).synchronize { results = self.class_variable_get(:@@database).execute("SELECT id from #{self.name}", []) }
      results.each {|r| yield self.new.load(r[0]) }
    end
  end
  
end
