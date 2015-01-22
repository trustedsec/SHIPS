#Base class for computer validation
#acts as a factor for child class instances

require_relative '../lib/computervalidator'

class ValidateSample < ComputerValidator
  
  def lookup(computerName)
    if computerName == 'Test'
      true
    else 
      false
    end
  end
  
end
