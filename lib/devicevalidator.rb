#Base Class for device validators

class DeviceValidator

  #do what USA::USER::Ident doess and have a shared set of class variables, that can be setup at program start
  #which are merged (overidden) with whatever is passed to new
  def initialize(optional={})
    @optional =  self.class.options.merge optional
  end

  def self.options=(v)
    @@optional = v
  end

  def self.options
    @@optional ||= Hash.new
  end

  def lookup(devicename)
    false
  end

  def self.new_of_type(type, *args)
    validator = ObjectSpace.each_object(Class).select {|klass| (klass < self) and (klass.name == type) }[0]
    validator.new(*args)
  end

end