require_relative 'devicevalidator'

class DeviceValidatorAny < DeviceValidator
  def lookup(devicename)
    true
  end
end