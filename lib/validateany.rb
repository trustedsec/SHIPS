#Base class for computer validation
#acts as a factor for child class instances

class ValidateAny < ComputerValidator
  
  def lookup(computerName)
    true
  end
  
end
