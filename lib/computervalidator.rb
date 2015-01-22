#Base class for computer validation
#acts as a factor for child class instances

class ComputerValidator
  
  def initialize(optional=nil)
    @optional = optional
  end
  
  def lookup(computerName)
  #True if computer is found in the data source
  #otherwise false
  #This is the only function that MUST be implemented
    false
  end
  
  def self.createObjects(optional)
    instances_of_children = Array.new
    ObjectSpace.each_object(Class).select {|klass| klass < self }.each do |c|
      instances_of_children << (c.new optional)  
    end
    instances_of_children
  end 
end
