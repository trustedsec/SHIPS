require_relative 'devicevalidator'
  require 'net/ldap'

  class DeviceValidatorLDAP < DeviceValidator

    def initialize(optional={})
      super optional
      @ldap = Net::LDAP.new
      @ldap.host = @optional[:DeviceValidatorLDAP_host]
      @ldap.port = @optional[:DeviceValidatorLDAP_port].to_i
      @ldap.encryption @optional[:DeviceValidatorLDAP_encryption].to_sym if optional[:DeviceValidatorLDAP_encryption]
      @ldap.base = @optional[:DeviceValidatorLDAP_base]
      @ldap.auth @optional[:DeviceValidatorLDAP_username], @optional[:DeviceValidatorLDAP_password]
    end

    def lookup(devicename)
      filter1 = Net::LDAP::Filter.eq('objectClass', @optional[:DeviceValidatorLDAP_class])
      filter2 = Net::LDAP::Filter.eq(@optional[:DeviceValidatorLDAP_name_attribute], devicename)
      filter = Net::LDAP::Filter.join(filter1, filter2)
      scope = Net::LDAP::SearchScope_WholeSubtree
      if rs = @ldap.search({ :filter => filter,
                             :scope => scope,
                             :base => @optional[:DeviceValidatorLDAP_base]
                           })
        return false unless rs.count == 1
      else
        return false
      end
      true
    end
  end