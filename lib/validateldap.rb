require 'rubygems'
require 'ldap'
require_relative 'ldapfns'

class ValidateLDAP < ComputerValidator
include LdapFns  
  
  def initialize(optional=nil)
    super
    optionArgs(optional)
  end
  
  def lookup(computerName)
#binding.pry
    server = nil
    checkString(computerName)
    raise RuntimeError, 'LDAP Server Bind Failed' unless server = bindServer
    filter = "(&(objectclass=computer)(name=#{computerName}))"
    dn = findIn(server, @ldapComputerOU, filter) || nil
    server.unbind
    return true if dn
    false
  rescue
    server.unbind if server
    return false
  end
  
end
