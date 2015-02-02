require 'rubygems'
require 'ldap'

module LdapFns
  
  def self.included(base)
    base.send(:private, :bindServer)
    base.send(:private, :optionArgs)
    base.send(:private, :findIn)
    base.send(:private, :checkString)
  end
  
  def optionArgs(optional)
    optional ||= Hash.new
    @ldapGroupDN = optional['ldapGroupDN']
    @ldapUserOU = optional['ldapUserOU']
    @ldapComputerOU = optional['ldapComputerOU']
    @ldapServer = optional['ldapServer']
    @ldapPort = optional['ldapPort']
    @ldapUserDn = optional['ldapUserDN']
    @ldapPassword = optional['ldapPassword']  
  end

  def bindServer(user=nil, password=nil)
    user ||= @ldapUserDn
    password ||= @ldapPassword
    server = LDAP::Conn.new(@ldapServer, @ldapPort)
    server.set_option( LDAP::LDAP_OPT_REFERRALS, 0)
    server.set_option( LDAP::LDAP_OPT_PROTOCOL_VERSION, 3 )
    if server.bind(user, password)
      return server
    end
    nil
  end
  
  def checkString(v)
    safe = 0
    v.each_char { |c| safe += 1 if  (["\\", '|', '(', ')', '*', '=', '/', '&', '<', '>'].include? c) }
    raise ArgumentError, 'String contains disallowed characters'  unless safe == 0
  end
  
  def findIn(server, ou, filter)
    scope = LDAP::LDAP_SCOPE_SUBTREE
    attrs = ['dn']
    r = server.search2(ou, scope, filter, attrs)
    if ( 1 == r.length )
      return r[0]['dn'][0]
    end
    nil
  end
  
end
