require 'rubygems'
require 'ldap'
require_relative 'ldapfns'

class IdentLDAP < WEBrick::USA::User::Identity

include LdapFns

  def initialize(optional=nil)
    super
    optionArgs(optional)
  end
  
  def login(form_data)
    server = nil
    user = form_data['username'].force_encoding('UTF-8')
    pass = form_data['password'].force_encoding('UTF-8')
    checkString(user)
    raise RuntimeError, 'LDAP Server Bind Failded' unless server = bindServer
    filter = "(&(objectclass=user)(sAMAccountName=#{user})(memberof=#{@ldapGroupDN}))"
    return false unless  dn = findIn(server, @ldapUserOU, filter)
    server.unbind
    server = nil
    if server = bindServer(dn, pass)
      @usertoken = user
      server.unbind
      return true 
    end
    false    
  rescue StandardError => e
    server.unbind if server
    @usertoken = nil
    return false
  end
  
  def self.form_inner_html
      <<WWWFORM
       <table><tbody>
       <tr>
       <td>User Name:</td>
       <td><input class="PlainTextIn" maxlength=50 name="username", type="text"></td>
       </tr>
       <tr>
       <td>Password:</td>
       <td><input class="PasswordIn" maxlength=255 name="password", type="password"></td>
       </tr> 
       </tbody></table>
WWWFORM
  end

end
